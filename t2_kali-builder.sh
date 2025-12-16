#!/bin/bash
# t2_kali-builder.sh - Universal T2 Kali ISO Builder
# Features: Multi-Distro Support, Auto-Cleanup, Verbose Logging, T2 Integration

set -e

# COLORS
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# GLOBAL CONFIG
WORK_DIR="live-build-config"
LOG_FILE="kali-build-$(date +%s).log"

# ==============================================================================
# 0. AUTO-CLEANUP TRAP (The "Janitor")
# ==============================================================================
cleanup() {
    EXIT_CODE=$?
    echo ""
    echo -e "${BLUE}[*] Cleaning up build artifacts...${NC}"
    
    # Rescue Log File
    if [ -f "$WORK_DIR/build.log" ]; then
        mv "$WORK_DIR/build.log" "./$LOG_FILE"
        echo -e "${GREEN}    -> Log saved to: ./$LOG_FILE${NC}"
    fi

    # Rescue ISO (If Successful)
    if ls "$WORK_DIR/images/"*.iso 1> /dev/null 2>&1; then
        mv "$WORK_DIR/images/"*.iso ./
        echo -e "${GREEN}    -> ISO moved to current directory.${NC}"
    fi

    # Nuke Build Directory
    if [ -d "$WORK_DIR" ]; then
        echo -e "${BLUE}    -> Deleting temporary build directory...${NC}"
        rm -rf "$WORK_DIR"
    fi

    if [ $EXIT_CODE -ne 0 ]; then
        echo -e "${RED}[!] Build Failed. Check $LOG_FILE for details.${NC}"
    else
        echo -e "${GREEN}[SUCCESS] Build Finished & Cleaned Up.${NC}"
    fi
}
# Trigger 'cleanup' on Exit, Error, or Ctrl+C
trap cleanup EXIT INT TERM

# ==============================================================================
# 1. PRE-FLIGHT CHECKS & DEPENDENCIES
# ==============================================================================
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[!] Please run as root (sudo ./t2_kali-builder.sh)${NC}"
  exit 1
fi

echo -e "${BLUE}[*] Detecting Operating System...${NC}"
if grep -qi "kali" /etc/os-release; then
    # --- KALI NATIVE ---
    echo -e "${GREEN}    -> Kali Linux detected. Installing standard tools.${NC}"
    apt-get update -qq
    apt-get install -y git live-build curl ca-certificates gnupg dirmngr
else
    # --- UBUNTU / POP!_OS / DEBIAN ---
    echo -e "${GREEN}    -> Non-Kali distro detected. Setting up compatibility layer...${NC}"
    apt-get update -qq
    apt-get install -y git curl ca-certificates gnupg dirmngr debootstrap

    # Remove bad distro version of live-build
    if dpkg -l | grep -q live-build; then
        apt-get remove -y live-build
    fi

    # Install Kali-specific tools manually
    wget -qO live-build.deb "http://http.kali.org/pool/main/l/live-build/live-build_20240810_all.deb"
    wget -qO kali-keyring.deb "http://http.kali.org/pool/main/k/kali-archive-keyring/kali-archive-keyring_2024.1_all.deb"
    
    dpkg -i live-build.deb kali-keyring.deb || apt-get install -f -y
    rm -f live-build.deb kali-keyring.deb
fi

# ==============================================================================
# 2. PREPARE BUILD DIRECTORY
# ==============================================================================
# Ensure clean start (in case trap failed previously)
if [ -d "$WORK_DIR" ]; then rm -rf "$WORK_DIR"; fi

echo -e "${BLUE}[*] Cloning official Kali live-build config...${NC}"
git clone https://gitlab.com/kalilinux/build-scripts/live-build-config.git "$WORK_DIR"
cd "$WORK_DIR"

# ==============================================================================
# 3. MANDATORY T2 CONFIGURATION (KERNEL + DRIVERS)
# ==============================================================================
echo -e "${GREEN}[+] Configuring T2 Repositories...${NC}"

# Create required directories
mkdir -p kali-config/common/archives/
mkdir -p kali-config/common/package-lists/
mkdir -p kali-config/common/includes.chroot/etc/apt/preferences.d/

# A. Add Keys & Repos
curl -L "https://adityagarg8.github.io/t2-ubuntu-repo/KEY.gpg" -o kali-config/common/archives/t2.key.chroot
cp kali-config/common/archives/t2.key.chroot kali-config/common/archives/t2.key.binary

# Common Repo (Fans/Touchbar)
curl -L "https://adityagarg8.github.io/t2-ubuntu-repo/t2.list" -o kali-config/common/archives/t2-common.list.chroot
cp kali-config/common/archives/t2-common.list.chroot kali-config/common/archives/t2-common.list.binary

# Release Repo (Kernel)
echo "deb [signed-by=/etc/apt/trusted.gpg.d/t2-ubuntu-repo.gpg] https://github.com/AdityaGarg8/t2-ubuntu-repo/releases/download/testing ./" > kali-config/common/archives/t2-release.list.chroot
cp kali-config/common/archives/t2-release.list.chroot kali-config/common/archives/t2-release.list.binary

# B. Add APT Pinning (Prioritize T2 Kernel)
cat <<EOF > kali-config/common/includes.chroot/etc/apt/preferences.d/99-t2-repo
Package: *
Pin: origin github.com
Pin-Priority: 1001

Package: *
Pin: release o=Aditya Garg
Pin-Priority: 1001
EOF

# C. Add T2 Packages
cat <<EOF > kali-config/common/package-lists/t2-support.list.chroot
linux-t2
apple-t2-audio-config
tiny-dfr
t2fanrd
EOF

# ==============================================================================
# 4. CUSTOM REPO WIZARD
# ==============================================================================
read -p "Add custom repositories (Floorp/VSCode)? [y/N]: " ADD_REPO
if [[ "$ADD_REPO" =~ ^[Yy]$ ]]; then
    REPO_COUNT=1
    while true; do
        echo -e "${GREEN}--- Custom Repo #$REPO_COUNT ---${NC}"
        
        echo "Enter 'deb' line (e.g. deb https://ppa.floorp.app/amd64/ ./):"
        read -r REPO_LINE
        echo "Enter GPG Key URL:"
        read -r REPO_KEY
        echo "Enter packages (space separated):"
        read -r REPO_PKGS

        SAFE_NAME="custom_repo_${REPO_COUNT}"
        
        # Write List
        echo "$REPO_LINE" > "kali-config/common/archives/${SAFE_NAME}.list.chroot"
        cp "kali-config/common/archives/${SAFE_NAME}.list.chroot" "kali-config/common/archives/${SAFE_NAME}.list.binary"
        
        # Download Key
        curl -L "$REPO_KEY" -o "kali-config/common/archives/${SAFE_NAME}.key.chroot"
        cp "kali-config/common/archives/${SAFE_NAME}.key.chroot" "kali-config/common/archives/${SAFE_NAME}.key.binary"

        # Add Packages
        if [ ! -z "$REPO_PKGS" ]; then
            echo "$REPO_PKGS" >> "kali-config/common/package-lists/custom.list.chroot"
        fi
        
        read -p "Add another? [y/N]: " CONT
        if [[ ! "$CONT" =~ ^[Yy]$ ]]; then break; fi
        ((REPO_COUNT++))
    done
fi

# ==============================================================================
# 5. VARIANT SELECTION & BUILD
# ==============================================================================
echo -e "${BLUE}Select Variant: 1)XFCE 2)Purple 3)GNOME 4)KDE 5)i3${NC}"
read -p "[1]: " VARIANT_NUM
case $VARIANT_NUM in
    2) VARIANT="purple" ;;
    3) VARIANT="gnome" ;;
    4) VARIANT="kde" ;;
    5) VARIANT="i3" ;;
    *) VARIANT="xfce" ;;
esac

echo -e "${GREEN}[*] Starting Build ($VARIANT)...${NC}"
echo "    Output will be mirrored to $LOG_FILE."

# Run Configuration
lb config -a amd64 --distribution kali-rolling -- --variant "$VARIANT"

# Run Build (Verbose + Log to file)
# '2>&1' captures errors, 'tee' writes to screen AND file
lb build --verbose 2>&1 | tee build.log

# Trap will handle final cleanup automatically!
