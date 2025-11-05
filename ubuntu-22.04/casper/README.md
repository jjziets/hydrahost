# Ubuntu 22.04 Casper Files

## Required Files

This directory needs two files extracted from the Ubuntu 22.04 live-server ISO:

- `vmlinuz` - Linux kernel (~14MB)
- `initrd` - Initial RAM disk (~95MB)

## How to Extract

### Option 1: Use the Extraction Script (Recommended)

```bash
cd ../..
./tools/extract-casper-files.sh 22.04
```

### Option 2: Manual Extraction

1. Download the Ubuntu 22.04.5 ISO:
   ```bash
   curl -L -O https://releases.ubuntu.com/jammy/ubuntu-22.04.5-live-server-amd64.iso
   ```

2. Extract casper files:
   
   **On macOS:**
   ```bash
   bsdtar -xf ubuntu-22.04.5-live-server-amd64.iso -C . casper/vmlinuz casper/initrd
   mv casper/* .
   rmdir casper
   ```

   **On Linux:**
   ```bash
   sudo mount -o loop ubuntu-22.04.5-live-server-amd64.iso /mnt
   cp /mnt/casper/vmlinuz .
   cp /mnt/casper/initrd .
   sudo umount /mnt
   ```

   **With 7-Zip:**
   ```bash
   7z e ubuntu-22.04.5-live-server-amd64.iso casper/vmlinuz casper/initrd
   ```

3. Verify files:
   ```bash
   ls -lh vmlinuz initrd
   # Should show:
   # vmlinuz: ~14MB
   # initrd:  ~95MB
   ```

## Git LFS

These files are large and should be tracked with Git LFS:

```bash
git lfs track "ubuntu-22.04/casper/initrd"
git add .gitattributes
git add ubuntu-22.04/casper/*
git commit -m "Add Ubuntu 22.04 casper files"
```

## Note

The files are **not included in this repository by default** due to their size. You must extract them before the iPXE boot will work.

