# Setup Instructions

## Initial Setup

Before using this repository for Ubuntu autoinstall, you need to extract the casper files (kernel and initrd) from the Ubuntu ISOs.

### Extract Casper Files

For each Ubuntu version you want to use:

```bash
# Ubuntu 22.04 (Recommended)
./tools/extract-casper-files.sh 22.04

# Ubuntu 20.04 (Legacy)
./tools/extract-casper-files.sh 20.04
```

**Note:** The ISO download is ~2GB and extraction takes 5-10 minutes.

### Manual Extraction

If the script doesn't work, see the README in each version's casper folder:
- `ubuntu-22.04/casper/README.md`
- `ubuntu-20.04/casper/README.md`

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

