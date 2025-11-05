# Ubuntu Autoinstall for Hydra Host - iPXE Network Boot

Automated Ubuntu installation on Hydra Host bare-metal servers using iPXE network boot and cloud-init autoinstall.

**Supports:**
- Ubuntu 25.04 (Plucky Puffin) 🆕 **Latest**
- Ubuntu 24.04 LTS (Noble Numbat) ⭐ **Recommended**
- Ubuntu 22.04 LTS (Jammy Jellyfish)
- Ubuntu 20.04 LTS (Focal Fossa) - Legacy support

---

## 🚀 Quick Start

### 1. Provision Server in Hydra Host Console

1. Go to the **Provision** tab for your server
2. Select **iPXE Custom** as the Operating System
3. Enter the iPXE URL for your desired Ubuntu version:

**Ubuntu 25.04 (Latest):**
```
https://raw.githubusercontent.com/jjziets/hydrahost/main/ubuntu-25.04/boot.ipxe
```

**Ubuntu 24.04 LTS (Recommended):**
```
https://raw.githubusercontent.com/jjziets/hydrahost/main/ubuntu-24.04/boot.ipxe
```

**Ubuntu 22.04 LTS:**
```
https://raw.githubusercontent.com/jjziets/hydrahost/main/ubuntu-22.04/boot.ipxe
```

**Ubuntu 20.04 LTS:**
```
https://raw.githubusercontent.com/jjziets/hydrahost/main/ubuntu-20.04/boot.ipxe
```

4. (Optional) Add your SSH public key
5. Click **Provision**

The server will boot, download the installer, and run a fully automated installation.

---

## 📋 What Gets Installed

### Default Configuration

- **User:** `ubuntu`
- **SSH:** Enabled with key-based auth (+ password fallback)
- **Networking:** DHCP on first available ethernet interface
- **Storage:** LVM on first disk (wipes existing data!)
- **Packages:** `openssh-server`, `curl`, `htop`, `nvme-cli`, `net-tools`
- **Console:** Serial console enabled for remote access
- **Post-install:** Automatic reboot

### Access After Installation

```bash
ssh ubuntu@<server-ip>
```

---

## 🎨 Customization

Each Ubuntu version has its own configuration directory:

```
ubuntu-22.04/
├── boot.ipxe           # iPXE boot script
├── casper/             # Kernel and initrd
│   ├── vmlinuz
│   └── initrd
└── autoinstall/        # Cloud-init autoinstall configs
    ├── user-data       # Main configuration
    └── meta-data       # Instance metadata

ubuntu-20.04/
└── (same structure)
```

### Customize Installation

Edit the `autoinstall/user-data` file for your chosen version to modify:

- **Hostname:** Change `identity.hostname`
- **Username/Password:** Update `identity.username` and `identity.password`
- **SSH Keys:** Replace keys in `ssh.authorized-keys`
- **Network:** Configure static IPs in `network.network`
- **Storage:** Customize `storage.layout`
- **Packages:** Add/remove packages in `packages`
- **Post-install scripts:** Modify `late-commands`

### Generate Password Hash

```bash
# On macOS
brew install whois
mkpasswd -m sha-512

# Or with Python
python3 -c "import crypt,getpass; print(crypt.crypt(getpass.getpass(), crypt.mksalt(crypt.METHOD_SHA512)))"
```

---

## 🏗️ Repository Structure

```
hydrahost/
├── ubuntu-25.04/               # Ubuntu 25.04 (Latest)
│   ├── boot.ipxe
│   ├── casper/
│   │   ├── vmlinuz
│   │   └── initrd
│   └── autoinstall/
│       ├── user-data
│       └── meta-data
│
├── ubuntu-24.04/               # Ubuntu 24.04 LTS (Recommended)
│   └── (same structure)
│
├── ubuntu-22.04/               # Ubuntu 22.04 LTS
│   └── (same structure)
│
├── ubuntu-20.04/               # Ubuntu 20.04 LTS (Legacy)
│   └── (same structure)
│
├── tools/                      # Shared utilities
│   ├── monitor-sol.sh         # IPMI SOL monitoring
│   ├── tail-sol.sh            # Log viewer
│   ├── diagnose-network.sh    # Network diagnostics
│   └── apply-bridge-nat-fix.sh # Bridge NAT configuration
│
├── internal/                   # Internal documentation (not in git)
├── .env.example               # IPMI credentials template
├── .gitignore
└── README.md                   # This file
```

---

## 🔧 Tools & Utilities

### Monitor Installation Progress

```bash
# 1. Configure IPMI credentials
cp .env.example .env
# Edit .env with your server's IPMI details

# 2. Start SOL monitoring
./tools/monitor-sol.sh

# 3. (Optional) Tail logs in another terminal
./tools/tail-sol.sh
```

### Network Diagnostics

```bash
./tools/diagnose-network.sh
```

Tests connectivity to GitHub and validates all boot files are accessible.

---

## 🌐 Network Requirements

### Provisioning Network Configuration

For custom iPXE boot to work, the Hydra Host bridge's provisioning network must provide:

1. **DHCP Gateway Option:** Clients need a default gateway to reach the internet
2. **NAT/Masquerading:** Provisioning network must have internet access

**See:** `internal/REQUIRED_KEA_CONFIG.md` for detailed configuration requirements.

---

## 🔍 Troubleshooting

### Boot Fails with "Network unreachable"

**Issue:** Provisioning network can't access the internet.

**Solution:** The bridge needs:
- DHCP option 3 (routers) configured in Kea
- NAT rule for provisioning network

See `internal/REQUIRED_KEA_CONFIG.md` for details.

### Installation Hangs or Fails

**Debug steps:**
1. Use `./tools/monitor-sol.sh` to watch the serial console
2. Check that SSH key is valid in `autoinstall/user-data`
3. Verify password hash is correctly formatted
4. Check network connectivity with `./tools/diagnose-network.sh`

### Can't SSH After Install

**Check:**
- Is the server reachable? `ping <server-ip>`
- Are you using the correct username? (default: `ubuntu`)
- Is your SSH key in `autoinstall/user-data`?
- Try password auth if key fails

---

## 📚 Documentation

### For Users
- This README - Quick start and customization
- `autoinstall/user-data` - Inline comments explain each option

### For Infrastructure Team
- `internal/REQUIRED_KEA_CONFIG.md` - Network configuration requirements
- `internal/QUICK_FIX_SUMMARY.md` - Executive summary of network setup
- `internal/BRIDGE_CHANGES_APPLIED.md` - Reference implementation

---

## 🆚 Ubuntu Version Comparison

| Feature | 25.04 | 24.04 LTS | 22.04 LTS | 20.04 LTS |
|---------|-------|-----------|-----------|-----------|
| **Release** | Apr 2025 | Apr 2024 | Apr 2022 | Apr 2020 |
| **Support Until** | Jan 2026 | Apr 2029 | Apr 2027 | Apr 2025 |
| **Kernel** | 6.13+ | 6.8 | 5.15 | 5.4 |
| **Status** | Latest | **LTS** | LTS | EOL Soon |
| **Recommended** | Testing | ✅ **Production** | Yes | Legacy |

**Recommendations:**
- **Production:** Use Ubuntu 24.04 LTS (longest support, stable)
- **Testing/Latest:** Use Ubuntu 25.04 (cutting edge features)
- **Legacy Systems:** Use Ubuntu 22.04 or 20.04 if needed

---

## ⚙️ Advanced Configuration

### Use Different Ubuntu Version

To add support for another Ubuntu version (e.g., 24.04):

1. Create directory: `ubuntu-24.04/`
2. Download and extract casper files from ISO
3. Copy and adapt `boot.ipxe` and `autoinstall/` configs
4. Update URLs in boot.ipxe

### Custom Kernel Parameters

Edit `boot.ipxe` and modify the `common_args` variable:

```ipxe
set common_args ip=dhcp url=${iso_url} autoinstall ds=nocloud-net\;s=${seed_url} your-param=value
```

### Static IP Configuration

Edit `autoinstall/user-data`:

```yaml
network:
  network:
    version: 2
    ethernets:
      eth0:
        addresses: [192.168.1.100/24]
        gateway4: 192.168.1.1
        nameservers:
          addresses: [8.8.8.8, 1.1.1.1]
```

---

## 📝 Notes

- Repository must be **public** for iPXE to fetch files
- Large files (initrd) use GitHub LFS
- Serial console defaults to `ttyS1` (adjust if needed)
- Installation is **fully automated** - verify configs before provisioning!

---

## 🤝 Contributing

1. Fork this repository
2. Create a feature branch
3. Customize for your use case
4. Share improvements via pull request

---

## 📄 License

See [LICENSE](LICENSE) file.

---

## 🔗 Resources

- [Ubuntu Autoinstall Documentation](https://ubuntu.com/server/docs/install/autoinstall)
- [Cloud-init Documentation](https://cloudinit.readthedocs.io/)
- [iPXE Documentation](https://ipxe.org/)
- [Hydra Host](https://hydrahost.com/)

---

**Status:** Production-ready for Ubuntu 22.04 LTS  
**Maintained by:** Hydra Host Community
