# Setup Instructions

## Initial Setup

Before using this repository for Ubuntu autoinstall, you need to extract the casper files (kernel and initrd) from the Ubuntu ISOs.

### Extract Casper Files

**✅ Casper files are already included in this repository!**

The repository includes pre-extracted casper files from live-server ISOs for all versions:
- Ubuntu 25.04 (Plucky Puffin)
- Ubuntu 24.04 LTS (Noble Numbat)
- Ubuntu 22.04 LTS (Jammy Jellyfish)
- Ubuntu 20.04 LTS (Focal Fossa)

**You can skip this step and go directly to usage.**

### Re-extract Casper Files (Optional)

If you need to update casper files (e.g., for a new Ubuntu point release):

```bash
# Download the ISO first (if not already present)
cd /path/to/hydrahost
curl -LO https://releases.ubuntu.com/jammy/ubuntu-22.04.5-live-server-amd64.iso

# Extract casper files
./tools/extract-casper-from-iso.sh 22.04
```

**Available for all versions:**
```bash
./tools/extract-casper-from-iso.sh 20.04
./tools/extract-casper-from-iso.sh 22.04
./tools/extract-casper-from-iso.sh 24.04
./tools/extract-casper-from-iso.sh 25.04
```

**Note:** The script will verify that extracted initrds are the correct size (70-150MB from live-server ISOs, not small d-i netboot files).

### Manual Extraction

If you need to extract manually:

```bash
# Using 7z (recommended)
7z x ubuntu-22.04.5-live-server-amd64.iso casper/vmlinuz casper/initrd -y

# Or using mount (Linux)
sudo mount -o loop ubuntu-22.04.5-live-server-amd64.iso /mnt
cp /mnt/casper/vmlinuz /mnt/casper/initrd ubuntu-22.04/casper/
sudo umount /mnt
```

**⚠️ Important:** Always extract from **live-server ISOs**, not netboot d-i files!

### Commit to Git

After extraction, commit the files (using Git LFS for large files):

```bash
git lfs track "*/casper/initrd"
git add .gitattributes
git add ubuntu-*/casper/*
git commit -m "Add Ubuntu casper files"
git push
```

## Testing

After setup, test with:

```bash
./tools/diagnose-network.sh
```

This verifies all boot files are accessible from GitHub.

---

**Next:** See [README.md](README.md) for usage instructions.

