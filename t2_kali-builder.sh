#!/bin/bash

# ==============================================================================
# SCRIPT: t2_kali-builder
# DESCRIPTION: A fully interactive wizard to build custom Kali Linux Live ISOs
#              with mandatory T2 Mac support.
# ==============================================================================

set -e # Exit immediately if a command exits with a non-zero status

# Default Variables
BUILD_DIR="live-build-config"
VARIANT=""

# Colors for pretty output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check for Root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root (sudo).${NC}"
    exit 1
fi

# ==============================================================================
# 1. WELCOME & DEPENDENCIES
# ==============================================================================
clear
echo -e "${GREEN}==============================================${NC}"
echo -e "${GREEN}       Kali Linux T2 ISO Builder Wizard       ${NC}"
echo -e "${GREEN}==============================================${NC}"
echo ""
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
# 2. MANDATORY T2 CONFIGURATION
# ==============================================================================
echo -e "${BLUE}[+] Configuring MANDATORY T2 Repository & Hooks...${NC}"

# A. Add Repository (Rolling/Testing)
echo "deb [signed-by=/etc/apt/trusted.gpg.d/t2-ubuntu-repo.gpg] https://github.com/AdityaGarg8/t2-ubuntu-repo/releases/download/testing ./" > kali-config/common/archives/t2.list.chroot
cp kali-config/common/archives/t2.list.chroot kali-config/common/archives/t2.list.binary

# B. Add Key
curl -L "https://adityagarg8.github.io/t2-ubuntu-repo/KEY.gpg" -o kali-config/common/archives/t2.key.chroot
cp kali-config/common/archives/t2.key.chroot kali-config/common/archives/t2.key.binary

# C. Add APT Pinning (Hook)
cat <<EOF > kali-config/common/includes.chroot/etc/apt/preferences.d/99-t2-repo
Package: *
Pin: origin github.com
Pin-Priority: 1001

Package: *
Pin: release o=Aditya Garg
Pin-Priority: 1001
EOF

# D. Add T2 Packages
cat <<EOF > kali-config/common/package-lists/t2-support.list.chroot
linux-t2
apple-t2-audio-config
EOF

echo -e "${GREEN}   -> T2 Support Configured.${NC}"
echo ""

# ==============================================================================
# 3. INTERACTIVE REPOSITORY WIZARD
# ==============================================================================
echo -e "${GREEN}>>> Custom Repository Wizard${NC}"
echo "Would you like to add any extra repositories (e.g., Floorp, VSCode)?"
read -p "Make selection [y/N]: " repo_choice

count=0
while [[ "$repo_choice" =~ ^[Yy]$ ]]; do
    count=$((count+1))
    echo -e "${BLUE}--- Adding Custom Repo #$count ---${NC}"

    # Get the repo line
    echo "Enter the full 'deb' line (e.g., deb https://ppa.ablaze.one/ ./):"
    read -r REPO_LINE

    # Get the key URL
    echo "Enter the URL to the GPG Key (e.g., https://ppa.ablaze.one/KEY.gpg):"
    read -r KEY_URL

    # Get specific packages
    echo "Enter any package names to install from this repo (space separated):"
    echo "(Leave blank if you just want the repo added but no specific install)"
    read -r PKG_NAMES

    # Write Configs
    if [ ! -z "$REPO_LINE" ]; then
        echo "$REPO_LINE" > "kali-config/common/archives/custom-$count.list.chroot"
        cp "kali-config/common/archives/custom-$count.list.chroot" "kali-config/common/archives/custom-$count.list.binary"
        echo -e "${GREEN}   -> Repo added.${NC}"
    fi

    if [ ! -z "$KEY_URL" ]; then
        curl -L "$KEY_URL" -o "kali-config/common/archives/custom-$count.key.chroot"
        cp "kali-config/common/archives/custom-$count.key.chroot" "kali-config/common/archives/custom-$count.key.binary"
        echo -e "${GREEN}   -> Key downloaded.${NC}"
    fi

    if [ ! -z "$PKG_NAMES" ]; then
        echo "$PKG_NAMES" >> "kali-config/common/package-lists/custom-apps.list.chroot
