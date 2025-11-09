#!/bin/bash
#
# Extract Casper Files from Ubuntu Live Server ISO
# Extracts vmlinuz and initrd from the live-server ISO (not netboot d-i)
#
# Usage: ./extract-casper-from-iso.sh <version>
# Example: ./extract-casper-from-iso.sh 22.04
#

set -e

VERSION=$1

if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 22.04"
    echo ""
    echo "Available versions: 20.04, 22.04, 24.04, 25.04"
    exit 1
fi

# Get the repo root directory (parent of tools/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

UBUNTU_DIR="${REPO_ROOT}/ubuntu-${VERSION}"
CASPER_DIR="${UBUNTU_DIR}/casper"

# Map version to ISO filename
case "$VERSION" in
    "20.04")
        ISO_FILE="${REPO_ROOT}/ubuntu-20.04.6-live-server-amd64.iso"
        ;;
    "22.04")
        ISO_FILE="${REPO_ROOT}/ubuntu-22.04.5-live-server-amd64.iso"
        ;;
    "24.04")
        ISO_FILE="${REPO_ROOT}/ubuntu-24.04.3-live-server-amd64.iso"
        ;;
    "25.04")
        ISO_FILE="${REPO_ROOT}/ubuntu-25.04-live-server-amd64.iso"
        ;;
    *)
        echo "Error: Unsupported version: $VERSION"
        echo "Supported: 20.04, 22.04, 24.04, 25.04"
        exit 1
        ;;
esac

# Check if ISO exists
if [ ! -f "$ISO_FILE" ]; then
    echo "Error: ISO file not found: $ISO_FILE"
    echo ""
    echo "Please download the ISO first:"
    echo "  cd ${REPO_ROOT}"
    case "$VERSION" in
        "20.04")
            echo "  curl -LO https://releases.ubuntu.com/focal/ubuntu-20.04.6-live-server-amd64.iso"
            ;;
        "22.04")
            echo "  curl -LO https://releases.ubuntu.com/jammy/ubuntu-22.04.5-live-server-amd64.iso"
            ;;
        "24.04")
            echo "  curl -LO https://releases.ubuntu.com/noble/ubuntu-24.04.3-live-server-amd64.iso"
            ;;
        "25.04")
            echo "  curl -LO https://releases.ubuntu.com/plucky/ubuntu-25.04-live-server-amd64.iso"
            ;;
    esac
    exit 1
fi

# Check if 7z is installed
if ! command -v 7z &> /dev/null; then
    echo "Error: 7z is not installed"
    echo ""
    echo "Install it with:"
    echo "  macOS:  brew install p7zip"
    echo "  Ubuntu: sudo apt-get install p7zip-full"
    echo "  CentOS: sudo yum install p7zip"
    exit 1
fi

echo "=== Extracting Casper Files for Ubuntu $VERSION ==="
echo "ISO:    $ISO_FILE"
echo "Output: $CASPER_DIR"
echo ""

# Create casper directory if it doesn't exist
mkdir -p "$CASPER_DIR"

# Extract casper files using 7z
cd "$UBUNTU_DIR"
echo "[1/2] Extracting vmlinuz and initrd from ISO..."
7z x "$ISO_FILE" casper/vmlinuz casper/initrd -y > /dev/null

echo "[2/2] Verifying extracted files..."
if [ ! -f "$CASPER_DIR/vmlinuz" ] || [ ! -f "$CASPER_DIR/initrd" ]; then
    echo "Error: Extraction failed!"
    exit 1
fi

# Show file sizes
echo ""
echo "✅ Done! Casper files extracted:"
ls -lh "$CASPER_DIR"

# Verify initrd size (should be large for live-server, not small d-i)
INITRD_SIZE=$(stat -f%z "$CASPER_DIR/initrd" 2>/dev/null || stat -c%s "$CASPER_DIR/initrd" 2>/dev/null)
INITRD_SIZE_MB=$((INITRD_SIZE / 1024 / 1024))

echo ""
echo "Initrd size: ${INITRD_SIZE_MB}MB"

if [ "$INITRD_SIZE_MB" -lt 50 ]; then
    echo "⚠️  WARNING: initrd is smaller than expected (< 50MB)"
    echo "   This might be a netboot d-i initrd, not a live-server casper initrd."
    echo "   Live-server initrds are typically 70-150MB."
else
    echo "✅ Initrd size looks correct (live-server casper initrd)"
fi

echo ""
echo "Next steps:"
echo "  1. Commit to git:"
echo "     git add ubuntu-${VERSION}/casper/"
echo "     git commit -m \"Update Ubuntu ${VERSION} casper files from live ISO\""
echo "     git push"
echo ""
echo "  2. Test boot with updated files"

