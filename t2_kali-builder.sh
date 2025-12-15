#!/bin/bash
# t2_kali-builder.sh - Automates building a custom Kali ISO for T2 Macs
# Updated: Removed 'simple-cdd-profiles' dependency; Fixed T2 Repo logic.

set -e # Exit immediately if a command exits with a non-zero status

# COLORS
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 1. PRE-FLIGHT CHECKS
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[!] Please run as root (sudo ./t2_kali-builder.sh)${NC}"
  exit 1
fi

echo -e "${BLUE}[*] Installing dependencies (git, live-build, curl)...${NC}"
# Removed 'simple-cdd-profiles' which was causing the 404 error
apt-get update -qq
apt-get install -y git live-build curl ca-certificates gnupg dirmngr

# 2. PREPARE BUILD DIRECTORY
WORK_DIR="live-build-config"
if [ -d "$WORK_DIR" ]; then
    echo -e "${BLUE}[!] Directory $WORK_DIR exists. Backing up...${NC}"
    mv "$WORK_DIR" "${WORK_DIR}_backup_$(date +%s)"
fi

echo -e "${BLUE}[*] Cloning official Kali live-build config...${NC}"
git clone https://gitlab.com/kalilinux/build-scripts/live-build-config.git "$WORK_DIR"
cd "$WORK_DIR"

# 3. MANDATORY T2 CONFIGURATION (KERNEL + DRIVERS)
echo -e "${GREEN}[+] Configuring MANDATORY T2 Repositories...${NC}"

# A. Add T2 GPG Key (Used by both repos)
curl -L "https://adityagarg8.github.io/t2-ubuntu-repo/KEY.gpg" -o kali-config/common/archives/t2.key.chroot
cp kali-config/common/archives/t2.key.chroot kali-config/common/archives/t2.key.binary

# B. Add "Common" Repository (Fans, Touchbar tools)
# This provides 't2fanrd', 'tiny-dfr', etc.
curl -L "https://adityagarg8.github.io/t2-ubuntu-repo/t2.list" -o kali-config/common/archives/t2-common.list.chroot
cp kali-config/common/archives/t2-common.list.chroot kali-config/common/archives/t2-common.list.binary

# C. Add "Release Specific" Repository (The Kernel)
# We use the 'testing' alias to ensure compatibility with Kali Rolling
echo "deb [signed-by=/etc/apt/trusted.gpg.d/t2-ubuntu-repo.gpg] https://github.com/AdityaGarg8/t2-ubuntu-repo/releases/download/testing ./" > kali-config/common/archives/t2-release.list.chroot
cp kali-config/common/archives/t2-release.list.chroot kali-config/common/archives/t2-release.list.binary

# D. Add APT Pinning (Hook) to prefer T2 Kernel over Kali Kernel
mkdir -p kali-config/common/includes.chroot/etc/apt/preferences.d/
cat <<EOF > kali-config/common/includes.chroot/etc/apt/preferences.d/99-t2-repo
Package: *
Pin: origin github.com
Pin-Priority: 1001

Package: *
Pin: release o=Aditya Garg
Pin-Priority: 1001
EOF

# E. Add T2 Packages to Install List
cat <<EOF > kali-config/common/package-lists/t2-support.list.chroot
linux-t2
apple-t2-audio-config
tiny-dfr
t2fanrd
EOF

# 4. CUSTOM REPO WIZARD (Floorp, VSCode, etc.)
echo -e "${BLUE}>>> Custom Repository Wizard${NC}"
read -p "Would you like to add any extra repositories (e.g., Floorp, VSCode)? [y/N]: " ADD_REPO
if [[ "$ADD_REPO" =~ ^[Yy]$ ]]; then
    REPO_COUNT=1
    while true; do
        echo ""
        echo -e "${GREEN}--- Adding Custom Repo #$REPO_COUNT ---${NC}"
        
        echo "Enter the full 'deb' line:" 
        echo "(Example: deb https://ppa.floorp.app/amd64/ ./)"
        read -r REPO_LINE
        
        echo "Enter the URL to the GPG Key:"
        read -r REPO_KEY
        
        echo "Enter any package names to install from this repo (space separated):"
        read -r REPO_PKGS

        # Clean inputs
        SAFE_NAME="custom_repo_${REPO_COUNT}"
        
        # Write List File
        echo "$REPO_LINE" > "kali-config/common/archives/${SAFE_NAME}.list.chroot"
        cp "kali-config/common/archives/${SAFE_NAME}.list.chroot" "kali-config/common/archives/${SAFE_NAME}.list.binary"
        
        # Download Key
        curl -L "$REPO_KEY" -o "kali-config/common/archives/${SAFE_NAME}.key.chroot"
        cp "kali-config/common/archives/${SAFE_NAME}.key.chroot" "kali-config/common/archives/${SAFE_NAME}.key.binary"

        # Add Packages to List
        if [ ! -z "$REPO_PKGS" ]; then
            echo "$REPO_PKGS" >> "kali-config/common/package-lists/custom.list.chroot"
        fi

        echo -e "${GREEN}   -> Repo added.${NC}"
        
        read -p "Add another repository? [y/N]: " CONT
        if [[ ! "$CONT" =~ ^[Yy]$ ]]; then
            break
        fi
        ((REPO_COUNT++))
    done
fi

# 5. VARIANT SELECTION
echo -e "${BLUE}>>> Select Desktop Environment${NC}"
echo "1) XFCE (Recommended/Lightweight)"
echo "2) Purple (Defensive Security)"
echo "3) GNOME (Modern/Touch)"
echo "4) KDE (Customizable)"
echo "5) i3 (Tiling/Minimal)"
read -p "Enter number [1]: " VARIANT_NUM

case $VARIANT_NUM in
    2) VARIANT="
