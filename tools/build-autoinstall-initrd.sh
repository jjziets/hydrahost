#!/bin/bash
#
# Build Custom Autoinstall Initrd Overlay
# Creates a lightweight initrd that contains autoinstall configuration
# Can be stacked on top of Ubuntu's base initrd
#
# Usage: ./build-autoinstall-initrd.sh <ubuntu-version>
# Example: ./build-autoinstall-initrd.sh 22.04
#

set -e

VERSION=$1

if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 22.04"
    exit 1
fi

UBUNTU_DIR="ubuntu-${VERSION}"
OUTPUT_FILE="${UBUNTU_DIR}/autoinstall-overlay.img"

if [ ! -d "$UBUNTU_DIR" ]; then
    echo "Error: Directory $UBUNTU_DIR not found"
    exit 1
fi

echo "=== Building Autoinstall Initrd Overlay for Ubuntu $VERSION ==="
echo ""

# Create temporary working directory
TEMP_DIR=$(mktemp -d)
echo "Working directory: $TEMP_DIR"

# Create initrd structure
echo "[1/4] Creating initrd structure..."
mkdir -p "$TEMP_DIR/autoinstall"
mkdir -p "$TEMP_DIR/scripts"

# Copy autoinstall configuration
echo "[2/4] Adding autoinstall configuration..."
cp "$UBUNTU_DIR/autoinstall/user-data" "$TEMP_DIR/autoinstall/"
cp "$UBUNTU_DIR/autoinstall/meta-data" "$TEMP_DIR/autoinstall/"

# Create a simple init script that makes configs available
cat > "$TEMP_DIR/scripts/autoinstall-setup.sh" << 'EOSCRIPT'
#!/bin/sh
# Make autoinstall configs available to cloud-init
mkdir -p /run/cloud-init
cp /autoinstall/user-data /run/cloud-init/user-data || true
cp /autoinstall/meta-data /run/cloud-init/meta-data || true
EOSCRIPT

chmod +x "$TEMP_DIR/scripts/autoinstall-setup.sh"

# Create the initrd
echo "[3/4] Building initrd archive..."
CURRENT_DIR=$(pwd)
cd "$TEMP_DIR"
find . | cpio -o -H newc | gzip -9 > "$CURRENT_DIR/$OUTPUT_FILE"
cd - > /dev/null

# Cleanup
echo "[4/4] Cleaning up..."
rm -rf "$TEMP_DIR"

# Show result
echo ""
echo "✅ Done! Autoinstall overlay created:"
ls -lh "$OUTPUT_FILE"
echo ""
echo "File size: $(du -h "$OUTPUT_FILE" | cut -f1)"
echo ""
echo "This overlay contains:"
echo "  - autoinstall/user-data"
echo "  - autoinstall/meta-data"
echo "  - scripts/autoinstall-setup.sh"
echo ""
echo "Usage in boot.ipxe:"
echo "  kernel \${casper}/vmlinuz ..."
echo "  initrd \${casper}/initrd"
echo "  initrd \${repo}/autoinstall-overlay.img  # ← Add this line"
echo "  boot"
echo ""
echo "Commit to repo:"
echo "  git add $OUTPUT_FILE"
echo "  git commit -m \"Add autoinstall overlay for Ubuntu $VERSION\""
echo "  git push"

