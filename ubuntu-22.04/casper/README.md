# Ubuntu 22.04 Casper Files

## Required Files

This directory needs two files extracted from the Ubuntu 22.04 live-server ISO:

- `vmlinuz` - Linux kernel (~14MB)
- `initrd` - Initial RAM disk (~95MB)

## Quick Extraction Methods

### Option 1: Use Provided Script (Automated)

```bash
cd ../..
./tools/extract-casper-files.sh 22.04
```

**Note:** Downloads ~2GB ISO which may be slow. See faster alternatives below.

### Option 2: Download ISO via Torrent (FASTEST)

```bash
# 1. Download torrent file
curl -O https://releases.ubuntu.com/jammy/ubuntu-22.04.5-live-server-amd64.iso.torrent

# 2. Open with torrent client (Transmission, qBittorrent, etc)
open ubuntu-22.04.5-live-server-amd64.iso.torrent

# 3. After download completes, extract:
bsdtar -xf ubuntu-22.04.5-live-server-amd64.iso casper/vmlinuz casper/initrd
mv casper/* ubuntu-22.04/casper/
rmdir casper
```

### Option 3: Download from Mirror (May be faster)

Try different Ubuntu mirrors:

```bash
# US Mirror
curl -L -O http://us.archive.ubuntu.com/ubuntu-releases/jammy/ubuntu-22.04.5-live-server-amd64.iso

# Or find fastest mirror at: https://launchpad.net/ubuntu/+cdmirrors
```

### Option 4: Manual Extraction (If you have the ISO)

**On macOS:**
```bash
cd /Users/hanneszietsman/Code/hydrahost
bsdtar -xf ubuntu-22.04.5-live-server-amd64.iso casper/vmlinuz casper/initrd
mv casper/* ubuntu-22.04/casper/
rmdir casper
```

**On Linux:**
```bash
sudo mkdir -p /mnt/iso
sudo mount -o loop ubuntu-22.04.5-live-server-amd64.iso /mnt/iso
cp /mnt/iso/casper/vmlinuz ubuntu-22.04/casper/
cp /mnt/iso/casper/initrd ubuntu-22.04/casper/
sudo umount /mnt/iso
```

**With 7-Zip:**
```bash
7z e ubuntu-22.04.5-live-server-amd64.iso casper/vmlinuz casper/initrd -o"ubuntu-22.04/casper/"
```

## Verify Extraction

```bash
ls -lh ubuntu-22.04/casper/
# Should show:
# vmlinuz: ~14MB
# initrd:  ~95MB
```

## Commit to Git

After extraction:

```bash
git add ubuntu-22.04/casper/*
git commit -m "Add Ubuntu 22.04 casper files"
git push
```

## Alternative: Download Pre-extracted Files

If someone on your team has already extracted these files, they can share just the `vmlinuz` and `initrd` files directly (much smaller than the full ISO).

---

## Troubleshooting

**ISO download is slow:**
- Use torrent (usually 10x faster)
- Try different mirror
- Download on faster connection and transfer files

**bsdtar not found:**
```bash
# macOS - should be pre-installed
which bsdtar

# Linux - install if needed
sudo apt-get install libarchive-tools
```

**No extraction tool available:**
- Download on another machine that has the tools
- Transfer just the vmlinuz and initrd files (total ~109MB)

---

**Note:** These files are **required** for Ubuntu 22.04 iPXE boot to work. The boot will fail without them.
