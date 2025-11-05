#!/bin/bash
#
# Build Complete Autoinstall Overlay with ISO Fetching Capability
# Includes curl binary and do_urlmount override (Brokkr-style)
#
# Usage: ./build-complete-overlay.sh <ubuntu-version> <arch>
# Example: ./build-complete-overlay.sh 22.04 amd64
#

set -e

VERSION=$1
ARCH=${2:-amd64}

if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version> [arch]"
    echo "Example: $0 22.04 amd64"
    echo "Arch: amd64 or arm64"
    exit 1
fi

UBUNTU_DIR="ubuntu-${VERSION}"
OUTPUT_FILE="${UBUNTU_DIR}/autoinstall-overlay.img"
CURL_VERSION="v8.11.0"

echo "=== Building Complete Autoinstall Overlay for Ubuntu $VERSION ($ARCH) ==="
echo ""

# Determine curl binary URL
case "$ARCH" in
    amd64|x86_64)
        CURL_URL="https://github.com/moparisthebest/static-curl/releases/download/${CURL_VERSION}/curl-amd64"
        CURL_ARCH="amd64"
        ;;
    arm64|aarch64)
        CURL_URL="https://github.com/moparisthebest/static-curl/releases/download/${CURL_VERSION}/curl-aarch64"
        CURL_ARCH="arm64"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# Create temporary working directory
TEMP_DIR=$(mktemp -d)
echo "Working directory: $TEMP_DIR"

# Create structure
echo "[1/6] Creating overlay structure..."
mkdir -p "$TEMP_DIR/autoinstall"
mkdir -p "$TEMP_DIR/scripts/casper-bottom"
mkdir -p "$TEMP_DIR/usr/bin"

# Copy autoinstall configuration
echo "[2/6] Adding autoinstall configuration..."
cp "$UBUNTU_DIR/autoinstall/user-data" "$TEMP_DIR/autoinstall/"
cp "$UBUNTU_DIR/autoinstall/meta-data" "$TEMP_DIR/autoinstall/"

# Download static curl
echo "[3/6] Downloading static curl for $CURL_ARCH..."
curl -L "$CURL_URL" -o "$TEMP_DIR/usr/bin/curl"
chmod +x "$TEMP_DIR/usr/bin/curl"
echo "  Downloaded: $(du -h "$TEMP_DIR/usr/bin/curl" | cut -f1)"

# Create do_urlmount override script (simplified version of Brokkr's)
echo "[4/6] Creating URL mount override script..."
cat > "$TEMP_DIR/scripts/do_urlmount_override" << 'EOSCRIPT'
#!/bin/sh
# ISO Download and Mount Override
# Downloads ISO over HTTP and mounts it (based on Brokkr's approach)

rc=1
modprobe "${MP_QUIET}" isofs

log_begin_msg "Downloading and mounting ISO from ${URL}"
log_end_msg

target=$(basename "$URL")
[ -z "$target" ] && target="ubuntu.iso"

# Retry logic: 12 attempts with 5-second delays
max_attempts=12
attempt=1

while [ $attempt -le $max_attempts ]; do
    log_begin_msg "Download attempt ${attempt}/${max_attempts}"
    log_end_msg
    
    if /usr/bin/curl --show-error --fail --location --insecure --connect-timeout 20 --max-time 300 --output "$target" "$URL"; then
        log_begin_msg "Download successful"
        log_end_msg
        
        # Try to mount the downloaded ISO
        if mount -o ro "$target" "$mountpoint"; then
            if is_casper_path "$mountpoint" && matches_uuid "$mountpoint"; then
                rc=0
                break
            else
                umount "$mountpoint"
            fi
        fi
        break
    else
        log_begin_msg "Download failed, attempt ${attempt}/${max_attempts}"
        log_end_msg
        
        if [ $attempt -lt $max_attempts ]; then
            sleep 5
        fi
    fi
    
    attempt=$((attempt + 1))
done

if [ $rc -ne 0 ]; then
    log_begin_msg "Failed to download or mount ISO after ${max_attempts} attempts"
    log_end_msg
fi

return $rc
EOSCRIPT

chmod +x "$TEMP_DIR/scripts/do_urlmount_override"

# Create casper-bottom hook for cloud-init
echo "[5/6] Creating cloud-init integration hooks..."
cat > "$TEMP_DIR/scripts/casper-bottom/01autoinstall" << 'EOSCRIPT'
#!/bin/sh

PREREQ=""
prereqs() { echo "$PREREQ"; }

case "$1" in
    prereqs) prereqs; exit 0 ;;
esac

. /scripts/casper-functions

log_begin_msg "Setting up autoinstall configuration"

# Create cloud-init seed directories
mkdir -p /root/var/lib/cloud/seed/nocloud-net
mkdir -p /root/etc/cloud/cloud.cfg.d

# Copy autoinstall configs
if [ -f /autoinstall/user-data ]; then
    cp /autoinstall/user-data /root/var/lib/cloud/seed/nocloud-net/user-data
    log_success_msg "Autoinstall user-data configured"
fi

if [ -f /autoinstall/meta-data ]; then
    cp /autoinstall/meta-data /root/var/lib/cloud/seed/nocloud-net/meta-data
    log_success_msg "Autoinstall meta-data configured"
fi

# Configure cloud-init datasource
cat > /root/etc/cloud/cloud.cfg.d/99-autoinstall.cfg << 'CLOUDCFG'
datasource_list: [ NoCloud ]
datasource:
  NoCloud:
    seedfrom: /var/lib/cloud/seed/nocloud-net/
CLOUDCFG

log_end_msg
exit 0
EOSCRIPT

chmod +x "$TEMP_DIR/scripts/casper-bottom/01autoinstall"

# Build the initrd
echo "[6/6] Building initrd archive..."
CURRENT_DIR=$(pwd)
cd "$TEMP_DIR"
find . | cpio -o -H newc | gzip -9 > "$CURRENT_DIR/$OUTPUT_FILE"
cd - > /dev/null

# Cleanup
rm -rf "$TEMP_DIR"

echo ""
echo "✅ Done! Complete overlay created:"
ls -lh "$OUTPUT_FILE"
echo ""
echo "Overlay contains:"
echo "  - Static curl binary ($CURL_ARCH)"
echo "  - ISO download/mount logic (do_urlmount_override)"
echo "  - Autoinstall cloud-init integration"
echo "  - Casper hooks for Ubuntu live boot"
echo ""
echo "This enables vanilla Ubuntu to boot from ISO over HTTP!"
echo ""
echo "Commit:"
echo "  git add $OUTPUT_FILE"
echo "  git commit -m \"Add complete overlay with ISO-fetching for Ubuntu $VERSION\""
echo "  git push"

