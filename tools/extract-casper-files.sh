#!/bin/bash
#
# Extract casper files (vmlinuz and initrd) from Ubuntu ISO
# Usage: ./extract-casper-files.sh <ubuntu-version>
#
# Example: ./extract-casper-files.sh 22.04
#

set -e

VERSION=$1

if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 22.04"
    exit 1
fi

# Determine ISO URL based on version
case "$VERSION" in
    "22.04")
        ISO_URL="https://releases.ubuntu.com/jammy/ubuntu-22.04.5-live-server-amd64.iso"
        ;;
    "20.04")
        ISO_URL="https://releases.ubuntu.com/focal/ubuntu-20.04.6-live-server-amd64.iso"
        ;;
    "24.04")
        ISO_URL="https://releases.ubuntu.com/noble/ubuntu-24.04.1-live-server-amd64.iso"
        ;;
    *)
        echo "Unsupported version: $VERSION"
        exit 1
        ;;
esac

ISO_FILE="ubuntu-${VERSION}-live-server-amd64.iso"
CASPER_DIR="ubuntu-${VERSION}/casper"

echo "=== Extracting Casper Files for Ubuntu $VERSION ==="
echo "ISO URL: $ISO_URL"
echo "Output: $CASPER_DIR"
echo ""

# Download ISO
if [ ! -f "$ISO_FILE" ]; then
    echo "[1/3] Downloading ISO (~2GB, this will take a while)..."
    curl -L -o "$ISO_FILE" "$ISO_URL"
else
    echo "[1/3] ISO already downloaded: $ISO_FILE"
fi

# Create output directory
mkdir -p "$CASPER_DIR"

# Extract casper files
echo "[2/3] Extracting vmlinuz and initrd from ISO..."

if command -v 7z &> /dev/null; then
    # Using 7zip
    7z e "$ISO_FILE" casper/vmlinuz -o"$CASPER_DIR" -y
    7z e "$ISO_FILE" casper/initrd -o"$CASPER_DIR" -y
elif command -v bsdtar &> /dev/null; then
    # Using bsdtar (available on macOS)
    bsdtar -xf "$ISO_FILE" -C "$CASPER_DIR" casper/vmlinuz casper/initrd
    mv "$CASPER_DIR/casper/"* "$CASPER_DIR/"
    rmdir "$CASPER_DIR/casper"
else
    # Try mounting (Linux)
    MOUNT_POINT=$(mktemp -d)
    echo "Mounting ISO to $MOUNT_POINT"
    sudo mount -o loop "$ISO_FILE" "$MOUNT_POINT"
    cp "$MOUNT_POINT/casper/vmlinuz" "$CASPER_DIR/"
    cp "$MOUNT_POINT/casper/initrd" "$CASPER_DIR/"
    sudo umount "$MOUNT_POINT"
    rmdir "$MOUNT_POINT"
fi

# Cleanup
echo "[3/3] Cleaning up..."
# Optionally remove ISO: rm -f "$ISO_FILE"

echo ""
echo "✅ Done! Files extracted to $CASPER_DIR:"
ls -lh "$CASPER_DIR"
echo ""
echo "Note: These files are large and should be committed with Git LFS:"
echo "  git lfs track \"$CASPER_DIR/initrd\""
echo "  git add .gitattributes"
echo "  git add $CASPER_DIR/*"
echo "  git commit -m \"Add Ubuntu $VERSION casper files\""

