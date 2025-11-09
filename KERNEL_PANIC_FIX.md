# Kernel Panic Fix - VFS: Unable to mount root fs

## Problem

Ubuntu 22.04 (and all versions) were experiencing kernel panics during boot:

```
Kernel panic - not syncing: VFS: Unable to mount root fs on unknown-block(0,0)
```

## Root Causes (TWO Issues!)

### Issue 1: Wrong Initrd Source (Fixed)
The casper `initrd` files were from the **netboot debian-installer** (d-i) instead of the **live-server ISO**. 

- Netboot d-i initrds are small (~10-20MB) and designed for the Debian installer
- They do NOT contain casper hooks needed for `boot=casper` parameter
- When the kernel boots with `boot=casper` but gets a d-i initrd, it cannot mount the root filesystem

### Issue 2: Git LFS Pointer Files ⚠️ **CRITICAL**

**GitHub serves LFS pointer files via `raw.githubusercontent.com`, not the actual binary!**

When iPXE downloads from:
```
https://raw.githubusercontent.com/USER/REPO/main/path/to/initrd
```

It gets a **133-byte text file** like this:
```
version https://git-lfs.github.com/spec/v1
oid sha256:1b8a42e409...
size 113036389
```

Instead of the 108MB initrd binary! This tiny pointer file is not a valid initramfs, causing the kernel panic.

**Solution:** Use GitHub's LFS media URL:
```
https://media.githubusercontent.com/media/USER/REPO/main/path/to/initrd
```

This serves the actual binary file from LFS storage.

## Solution

### 1. Extract Correct Casper Files from Live ISOs

All casper files must come from the **live-server ISO**, not netboot:

```bash
# Use the new extraction tool
./tools/extract-casper-from-iso.sh 22.04
```

**Verification:**
- Live-server initrds are 70-150MB (large)
- Netboot d-i initrds are 10-20MB (small)

### 2. Fix Git LFS URLs ⚠️ **CRITICAL FIX**

Changed from `raw.githubusercontent.com` to `media.githubusercontent.com` for LFS files:

**Before (broken - downloads LFS pointer):**
```ipxe
set casper https://raw.githubusercontent.com/jjziets/hydrahost/main/ubuntu-22.04/casper
initrd ${casper}/initrd  # Downloads 133-byte pointer file!
```

**After (working - downloads actual binary):**
```ipxe
set casper_initrd https://media.githubusercontent.com/media/jjziets/hydrahost/main/ubuntu-22.04/casper/initrd
initrd ${casper_initrd}  # Downloads 108MB initrd binary
```

**Why this matters:**
- `raw.githubusercontent.com` serves the Git object (LFS pointer for LFS files)
- `media.githubusercontent.com/media/` serves the actual LFS binary
- vmlinuz is NOT in LFS, so it works fine with raw URL
- initrd IS in LFS, so it MUST use media URL

### 3. Update Boot Parameters

Aligned all `boot.ipxe` files with Brokkr's proven working pattern:

**Before (broken):**
```ipxe
set common_args boot=casper url=${iso_url} ip=dhcp autoinstall ds=nocloud-net\;s=${seed_url}
kernel ${casper}/vmlinuz ${common_args} initrd=initrd.img initrd=autoinstall-overlay.img ${cons} ---
```

**After (working):**
```ipxe
set common_args boot=casper netboot=url nfsboot=auto ro network ip=dhcp url=${iso_url} autoinstall ds=nocloud-net\;s=${seed_url}
kernel ${casper_vmlinuz} ${common_args} ${cons} ---
```

**Key changes:**
- Added `nfsboot=auto` - enables automatic NFS boot detection
- Added `ro` - mount root filesystem read-only initially
- Added `network` - ensure network is initialized early
- Removed explicit `initrd=...` kernel parameters (iPXE handles this)
- Split casper into separate vmlinuz and initrd URLs

### 4. Console Selection Menu

Added consistent console selection menu to all versions (20.04, 22.04, 24.04, 25.04):

```ipxe
:menu
menu Ubuntu XX.XX Server - Console Selection
item s0  Serial ttyS0 (115200)
item s1  Serial ttyS1 (115200)
item vga VGA console
choose --timeout 10000 --default s1 sel || goto menu
```

This allows the boot to work on different hardware with different serial port configurations.

## Files Changed

### Boot Configuration
- `ubuntu-20.04/boot.ipxe` - Updated kernel parameters and added console menu
- `ubuntu-22.04/boot.ipxe` - Updated kernel parameters and added console menu
- `ubuntu-24.04/boot.ipxe` - Already correct (no changes needed)
- `ubuntu-25.04/boot.ipxe` - Already correct (no changes needed)

### Casper Files
- `ubuntu-20.04/casper/initrd` - Extracted from live ISO (84MB)
- `ubuntu-20.04/casper/vmlinuz` - Extracted from live ISO (13MB)
- `ubuntu-22.04/casper/initrd` - Extracted from live ISO (108MB)
- `ubuntu-22.04/casper/vmlinuz` - Extracted from live ISO (11MB)
- `ubuntu-24.04/casper/initrd` - Extracted from live ISO (71MB)
- `ubuntu-24.04/casper/vmlinuz` - Extracted from live ISO (14MB)
- `ubuntu-25.04/casper/initrd` - Extracted from live ISO (76MB)
- `ubuntu-25.04/casper/vmlinuz` - Extracted from live ISO (15MB)

### New Tools
- `tools/extract-casper-from-iso.sh` - Automated extraction script with verification

## Testing

To test the fix:

1. **Start SOL monitoring:**
   ```bash
   ./tools/monitor-sol.sh
   ```

2. **Boot the server** using the updated iPXE URL

3. **Expected behavior:**
   - Console selection menu appears (10 second timeout)
   - Kernel boots with correct parameters
   - Casper mounts the ISO successfully
   - Autoinstall proceeds without kernel panic

4. **Watch for:**
   - No "VFS: Unable to mount root fs" errors
   - Successful ISO download and mount
   - Cloud-init autoinstall starting

## Prevention

**DO NOT use these scripts for casper extraction:**
- ❌ `tools/download-casper-direct.sh` - Downloads d-i netboot files (wrong!)
- ❌ Manual netboot downloads from `archive.ubuntu.com/.../netboot/`

**DO use:**
- ✅ `tools/extract-casper-from-iso.sh` - Extracts from live-server ISO (correct!)
- ✅ Manual extraction from live-server ISOs using 7z or mount

## Reference

Working example from Brokkr (bridge-api):
- `bridge-api/bridge/assets/ipxe/brokkr_live.ipxe.j2`
- Uses same kernel parameters: `boot=casper netboot=url nfsboot=auto ro network`

## How to Verify LFS URLs

Test if a file is being served correctly:

```bash
# Wrong URL (gets LFS pointer):
curl -sL "https://raw.githubusercontent.com/jjziets/hydrahost/main/ubuntu-22.04/casper/initrd" | head -1
# Output: version https://git-lfs.github.com/spec/v1

# Correct URL (gets binary):
curl -sL "https://media.githubusercontent.com/media/jjziets/hydrahost/main/ubuntu-22.04/casper/initrd" | head -c 20 | xxd
# Output: 00000000: 3037 3037 3031 3030 3030 3030 3030 3030  0707010000000000
```

## Summary

The kernel panic was caused by **TWO issues**:
1. Using wrong initrd source (debian-installer instead of live-server casper)
2. **Git LFS pointer files being downloaded instead of actual binaries** ⚠️

The fix:
1. Extract casper files from live-server ISOs (not netboot)
2. **Use `media.githubusercontent.com/media/` for LFS files** (initrd)
3. Use `raw.githubusercontent.com` for non-LFS files (vmlinuz, configs)
4. Use correct kernel parameters (`nfsboot=auto ro network`)
5. Add console selection for hardware compatibility

All versions (20.04, 22.04, 24.04, 25.04) now use the same proven pattern.

**The LFS URL fix is the most critical change** - without it, iPXE downloads a 133-byte text file instead of a 70-150MB initrd!

