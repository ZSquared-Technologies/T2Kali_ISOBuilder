#!/bin/bash

# ==============================================================================
# SCRIPT: Kali Linux T2 ISO Builder
# DESCRIPTION: Automates building a custom Kali Live ISO with mandatory T2 Mac
#              support (drivers + hooks) and allows custom repositories/variants.
# ==============================================================================

set -e # Exit immediately if a command exits with a non-zero status

# Default Variables
BUILD_DIR="live-build-config"
VARIANT=""
EXTRA_REPOS=() # Array to store custom repos "REPO_LINE|KEY_URL"

# Colors for pretty output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Helper Function: Print Usage
usage() {
    echo -e "${BLUE}Usage: $0 [OPTIONS]${NC}"
    echo -e "Options:"
    echo -e "  -v, --variant <name>     Specify the Kali variant (xfce, gnome, purple, kde, etc.)"
    echo -e "  -r, --repo <string>      Add a custom repository. Format: \"DEB_LINE|KEY_URL\""
    echo -e "                           Example: -r \"deb https://ppa.ablaze.one/ ./|https://ppa.ablaze.one/KEY.gpg\""
    echo -e "  -h, --help               Show this help message"
    echo ""
    echo -e "Example:"
    echo -e "  sudo $0 --variant xfce --repo \"deb https://ppa.ablaze.one/ ./|https://ppa.ablaze.one/KEY.gpg\""
    exit 1
}

# Parse Command Line Arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -v|--variant) VARIANT="$2"; shift ;;
        -r|--repo) EXTRA_REPOS+=("$2"); shift ;;
        -h|--help) usage ;;
        *) echo -e "${RED}Unknown parameter passed: $1${NC}"; usage ;;
    esac
    shift
done

# Check for Root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root (sudo).${NC}"
    exit 1
fi

# ==============================================================================
# 1. INTERACTIVE VARIANT SELECTION (If not provided via flag)
# ==============================================================================
if [ -z "$VARIANT" ]; then
    echo -e "${BLUE}No variant specified. Please select a Desktop Environment:${NC}"
    options=("xfce" "purple" "gnome" "kde" "mate" "lxde" "i3")
    select opt in "${options[@]}"; do
        if [[ " ${options[*]} " =~ " ${opt} " ]]; then
            VARIANT=$opt
            break
        else
            echo "Invalid option. Try again."
        fi
    done
fi

echo -e "${GREEN}>>> Building Kali Linux ($VARIANT) with T2 Support...${NC}"

# ==============================================================================
# 2. DEPENDENCIES & SETUP
# ==============================================================================
echo -e "${BLUE}[+] Installing build dependencies...${NC}"
apt update && apt install -y git live-build simple-cdd cdebootstrap curl

if [ -d "$BUILD_DIR" ]; then
    echo -e "${BLUE}[+] Cleaning up existing build directory...${NC}"
    rm -rf "$BUILD_DIR"
fi

echo -e "${BLUE}[+] Cloning live-build-config...${NC}"
git clone https://gitlab.com/kalilinux/build-scripts/live-build-config.git "$BUILD_DIR"
cd "$BUILD_DIR"

# Create common directory structure
mkdir -p kali-config/common/archives
mkdir -p kali-config/common/package-lists
mkdir -p kali-config/common/includes.chroot/etc/apt/preferences.d/

# ==============================================================================
# 3. MANDATORY T2 CONFIGURATION (Repo + Hook/Pinning)
# ==============================================================================
echo -e "${BLUE}[+] Configuring MANDATORY T2 Repository & Hooks...${NC}"

# A. Add Repository (Using 'testing' alias for rolling updates)
echo "deb [signed-by=/etc/apt/trusted.gpg.d/t2-ubuntu-repo.gpg] https://github.com/AdityaGarg8/t2-ubuntu-repo/releases/download/testing ./" > kali-config/common/archives/t2.list.chroot
cp kali-config/common/archives/t2.list.chroot kali-config/common/archives/t2.list.binary

# B. Add Key
curl -L "https://adityagarg8.github.io/t2-ubuntu-repo/KEY.gpg" -o kali-config/common/archives/t2.key.chroot
cp kali-config/common/archives/t2.key.chroot kali-config/common/archives/t2.key.binary

# C. Add APT Pinning (The "Hook" to force T2 Kernel priority)
cat <<EOF > kali-config/common/includes.chroot/etc/apt/preferences.d/99-t2-repo
Package: *
Pin: origin github.com
Pin-Priority: 1001

Package: *
Pin: release o=Aditya Garg
Pin-Priority: 1001
EOF

# D. Add T2 Packages to the install list
# We append to a specific T2 list file
cat <<EOF > kali-config/common/package-lists/t2-support.list.chroot
linux-t2
apple-t2-audio-config
EOF

# ==============================================================================
# 4. CUSTOM REPOSITORIES (User Provided)
# ==============================================================================
count=0
for entry in "${EXTRA_REPOS[@]}"; do
    count=$((count+1))

    # Split the input "REPO|KEY" into variables
    REPO_LINE="${entry%%|*}"
    KEY_URL="${entry##*|}"

    echo -e "${BLUE}[+] Adding Custom Repo #$count...${NC}"
    echo -e "    Repo: $REPO_LINE"
    echo -e "    Key:  $KEY_URL"

    # Write List File
    echo "$REPO_LINE" > "kali-config/common/archives/custom-$count.list.chroot"
    cp "kali-config/common/archives/custom-$count.list.chroot" "kali-config/common/archives/custom-$count.list.binary"

    # Download Key
    if [ "$KEY_URL" != "$entry" ]; then # Only try if a key was actually provided
        curl -L "$KEY_URL" -o "kali-config/common/archives/custom-$count.key.chroot"
        cp "kali-config/common/archives/custom-$count.key.chroot" "kali-config/common/archives/custom-$count.key.binary"
    fi
done

# If Floorp was one of the custom repos, we ensure it's installed
# (Simple check: if the user added the floorp repo URL, add package 'floorp')
for entry in "${EXTRA_REPOS[@]}"; do
    if [[ "$entry" == *"floorp"* ]] || [[ "$entry" == *"ablaze"* ]]; then
        echo "floorp" >> kali-config/common/package-lists/custom-apps.list.chroot
    fi
done

# ==============================================================================
# 5. BUILD EXECUTION
# ==============================================================================
echo -e "${GREEN}>>> Starting Build Process for Variant: $VARIANT${NC}"
echo -e "${GREEN}>>> This will take a long time. Go grab a coffee.${NC}"

./build.sh --variant "$VARIANT" --verbose

echo -e "${GREEN}>>> Build Complete! Check the 'images/' directory.${NC}"
