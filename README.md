# Hydra Host – Ubuntu 20.04.6 iPXE Autoinstall Example

This repository provides a **ready-to-use iPXE script** and **autoinstall configuration** to deploy **Ubuntu 20.04.6 LTS (Focal)** on Hydra Host bare-metal servers.

It is intended as a working example you can clone and customize for your own provisioning workflows.

---

## 🚀 How to Provision on Hydra Host

1. Go to the **Provision** tab of your server in the Hydra Host console.

2. In the **Operating System** dropdown, select **iPXE Custom**.

3. In the iPXE URL input, paste:

   ```
   https://raw.githubusercontent.com/jjziets/hydrahost/main/boot.ipxe
   ```

4. (Recommended) Click **Create SSH Key** and add your SSH public key.

   * The installer will provision the `ubuntu` user with this key.
   * Password login is also enabled as a fallback.

5. Click **Provision**.

   * The server will reboot, chainload iPXE, and run a fully unattended Ubuntu 20.04.6 installation.
   * When complete, you can SSH in using your key or your password.

---

## 🔑 Access After Install

* Default user: `ubuntu`
* SSH key: your Hydra console key (or any you baked into `user-data`)
* Password: fallback password you define in `user-data`

Example:

```bash
ssh ubuntu@<your-server-ip>
```

---

## 🛠️ What’s Inside

* **`boot.ipxe`**
  iPXE script that loads the Ubuntu 20.04.6 kernel + initrd from this repo and points to Canonical’s ISO.

* **`casper/`**
  Contains `vmlinuz` and `initrd` extracted from the official Ubuntu 20.04.6 Live Server ISO.

* **`autoinstall/`**

  * `user-data`: cloud-init config (autoinstall).
  * `meta-data`: NoCloud metadata.

* **ISO Payload**
  Installer fetches the base system from:
  [ubuntu-20.04.6-live-server-amd64.iso](https://releases.ubuntu.com/focal/ubuntu-20.04.6-live-server-amd64.iso)

---

## 📋 Default Autoinstall Behavior

* Language/locale: `en_US.UTF-8`
* Keyboard layout: `us`
* Hostname: `hydra-node`
* User: `ubuntu`

  * SSH key authentication enabled
  * Password login enabled as backup (SHA-512 hash in `user-data`)
* Networking: DHCP on any NIC matching `e*` (covers `enp*`, `ens*`, `eno*`)
* Storage: wipe first disk, create LVM root + swap
* Packages: `openssh-server`, `curl`, `htop`, `nvme-cli`
* Serial console: enabled on `ttyS0` and `ttyS1`
* Autoreboot after install

---

## 📝 Customizing

You can edit [`autoinstall/user-data`](autoinstall/user-data) to adjust:

* **Hostname**
* **SSH keys** (under `ssh.authorized-keys`)
* **Password hash** (under `identity.password`)
* **Storage layout** (pin to `/dev/nvme0n1` or RAID config)
* **Networking** (replace DHCP with static IP config)
* **Packages** (add your own list)

---

## 🔑 Generating a Password Hash

Passwords must be SHA-512 hashed for use in cloud-init.

On macOS or Linux:

```bash
brew install whois   # macOS only
mkpasswd -m sha-512
```

Or with Python:

```bash
python3 - <<'PY'
import crypt, getpass
print(crypt.crypt(getpass.getpass("Password: "), crypt.mksalt(crypt.METHOD_SHA512)))
PY
```

Copy the `$6$...` string into `identity.password` in [`user-data`](autoinstall/user-data).

---

## 📂 Repo Layout

```
boot.ipxe                # main iPXE script
casper/                  # kernel + initrd extracted from ISO
autoinstall/
  ├─ user-data           # autoinstall config
  └─ meta-data           # NoCloud metadata
```

---

## 🔧 Bridge Network Configuration (Required for Custom iPXE)

**Important:** For custom iPXE boot to work, the provisioning network must have internet access to download boot files from GitHub.

If you encounter "Network unreachable" errors during iPXE chainload, the bridge servers need a NAT configuration fix.

### Quick Fix

Run this on each bridge server:
```bash
sudo ./apply-bridge-nat-fix.sh
```

### Documentation

* **[QUICK_FIX_SUMMARY.md](QUICK_FIX_SUMMARY.md)** - Executive summary of the issue and fix
* **[BRIDGE_NAT_FIX.md](BRIDGE_NAT_FIX.md)** - Detailed technical explanation and multiple fix options
* **[apply-bridge-nat-fix.sh](apply-bridge-nat-fix.sh)** - Automated script to apply the fix

### What This Fixes

The provisioning network (`10.230.12.0/24`) needs NAT/masquerading to access the internet. Without this, iPXE clients cannot download boot scripts from external URLs like GitHub.

---

## 🐛 Debugging & Monitoring

### Monitor Deployment via IPMI SOL

Watch the deployment process in real-time using Serial Over LAN:

```bash
# 1. Configure IPMI credentials
cp .env.example .env
# Edit .env with your IPMI details

# 2. Start monitoring
./monitor-sol.sh

# 3. In another terminal, tail the logs
./tail-sol.sh
```

### Network Diagnostics

Test connectivity to GitHub and verify boot files are accessible:

```bash
./diagnose-network.sh
```

---

## ⚠️ Notes

* This repo must stay **public** so iPXE can fetch kernel/initrd and autoinstall seed.
* GitHub LFS is used for `casper/initrd` (large file). For large-scale deployments, mirror to your own CDN.
* `boot.ipxe` defaults to `console=ttyS1`. Adjust to `ttyS0` if your hardware uses that.
* Autoinstall is fully unattended — ensure your SSH key or password is correct before provisioning.

---

## ✅ Next Steps

* Provision a node in Hydra Host with this example.
* SSH in as `ubuntu` with your key or password.
* Fork this repo and customize `user-data` for your team’s needs.

