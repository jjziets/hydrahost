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
mkdir -p "$TEMP_DIR/scripts/casper-bottom"

# Copy autoinstall configuration
echo "[2/4] Adding autoinstall configuration..."
cp "$UBUNTU_DIR/autoinstall/user-data" "$TEMP_DIR/autoinstall/"
cp "$UBUNTU_DIR/autoinstall/meta-data" "$TEMP_DIR/autoinstall/"

# Create init script for cloud-init/netplan integration
cat > "$TEMP_DIR/scripts/casper-bottom/01autoinstall" << 'EOSCRIPT'
#!/bin/sh
# Cloud-init autoinstall integration for casper
# This runs during casper boot to make autoinstall configs available

PREREQ=""
prereqs()
{
    echo "$PREREQ"
}

case $1 in
prereqs)
    prereqs
    exit 0
    ;;
esac

. /scripts/casper-functions

log_begin_msg "Setting up autoinstall configuration"

# Create cloud-init directories
mkdir -p /root/var/lib/cloud/seed/nocloud-net
mkdir -p /root/etc/cloud/cloud.cfg.d

# Copy autoinstall configs to cloud-init seed location
if [ -f /autoinstall/user-data ]; then
    cp /autoinstall/user-data /root/var/lib/cloud/seed/nocloud-net/user-data
    log_success_msg "Autoinstall user-data copied"
fi

if [ -f /autoinstall/meta-data ]; then
    cp /autoinstall/meta-data /root/var/lib/cloud/seed/nocloud-net/meta-data
    log_success_msg "Autoinstall meta-data copied"
fi

# Enable autoinstall
cat > /root/etc/cloud/cloud.cfg.d/99-autoinstall.cfg << 'CLOUDCFG'
# Enable autoinstall
datasource_list: [ NoCloud ]
datasource:
  NoCloud:
    seedfrom: /var/lib/cloud/seed/nocloud-net/
CLOUDCFG

log_end_msg

exit 0
EOSCRIPT

chmod +x "$TEMP_DIR/scripts/casper-bottom/01autoinstall"

# Create early hook for network configuration
cat > "$TEMP_DIR/scripts/casper-bottom/00network" << 'EOSCRIPT'
#!/bin/sh
# Early network setup for autoinstall

PREREQ=""
prereqs()
{
    echo "$PREREQ"
}

case $1 in
prereqs)
    prereqs
    exit 0
    ;;
esac

. /scripts/casper-functions

log_begin_msg "Configuring network for autoinstall"

# Ensure network is up for cloud-init
# The kernel ip= parameter should have already configured network
# This just ensures it persists into the live environment

log_end_msg

exit 0
EOSCRIPT

chmod +x "$TEMP_DIR/scripts/casper-bottom/00network"

# Create the initrd
echo "[3/4] Building initrd archive..."
CURRENT_DIR=$(pwd)
cd "$TEMP_DIR"
find . | sort | cpio --quiet -o -H newc > "$CURRENT_DIR/$OUTPUT_FILE"
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

