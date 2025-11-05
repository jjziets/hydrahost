#!/bin/bash
#
# Download casper files directly without full ISO
# Faster alternative to extracting from ISO
#
# Usage: ./download-casper-direct.sh <version>
# Example: ./download-casper-direct.sh 22.04
#

set -e

VERSION=$1

if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 22.04"
    exit 1
fi

CASPER_DIR="ubuntu-${VERSION}/casper"

echo "=== Downloading Casper Files for Ubuntu $VERSION ==="
echo "Output: $CASPER_DIR"
echo ""

mkdir -p "$CASPER_DIR"

case "$VERSION" in
    "22.04")
        echo "[1/2] Downloading vmlinuz (~14MB)..."
        curl --connect-timeout 10 --max-time 120 -L \
            "http://archive.ubuntu.com/ubuntu/dists/jammy-updates/main/installer-amd64/current/legacy-images/netboot/ubuntu-installer/amd64/linux" \
            -o "$CASPER_DIR/vmlinuz.tmp" && mv "$CASPER_DIR/vmlinuz.tmp" "$CASPER_DIR/vmlinuz"
        
        echo "[2/2] Downloading initrd (~70MB)..."
        curl --connect-timeout 10 --max-time 300 -L \
            "http://archive.ubuntu.com/ubuntu/dists/jammy-updates/main/installer-amd64/current/legacy-images/netboot/ubuntu-installer/amd64/initrd.gz" \
            -o "$CASPER_DIR/initrd.tmp" && mv "$CASPER_DIR/initrd.tmp" "$CASPER_DIR/initrd"
        ;;
        
    "20.04")
        echo "[1/2] Downloading vmlinuz (~11MB)..."
        curl --connect-timeout 10 --max-time 120 -L \
            "http://archive.ubuntu.com/ubuntu/dists/focal-updates/main/installer-amd64/current/legacy-images/netboot/ubuntu-installer/amd64/linux" \
            -o "$CASPER_DIR/vmlinuz.tmp" && mv "$CASPER_DIR/vmlinuz.tmp" "$CASPER_DIR/vmlinuz"
        
        echo "[2/2] Downloading initrd (~50MB)..."
        curl --connect-timeout 10 --max-time 300 -L \
            "http://archive.ubuntu.com/ubuntu/dists/focal-updates/main/installer-amd64/current/legacy-images/netboot/ubuntu-installer/amd64/initrd.gz" \
            -o "$CASPER_DIR/initrd.tmp" && mv "$CASPER_DIR/initrd.tmp" "$CASPER_DIR/initrd"
        ;;
        
    *)
        echo "Unsupported version: $VERSION"
        echo "Supported: 22.04, 20.04"
        exit 1
        ;;
esac

echo ""
echo "✅ Done! Files downloaded to $CASPER_DIR:"
ls -lh "$CASPER_DIR"
echo ""
echo "Note: These are netboot files, not live-server casper files."
echo "They will work for basic installation but may have different behavior."
echo ""
echo "To commit:"
echo "  git add $CASPER_DIR/*"
echo "  git commit -m \"Add Ubuntu $VERSION casper files\""
echo "  git push"

