# Automated Gentoo Linux Installer (OpenRC + Btrfs + Binpkgs)

A highly efficient, modular two-stage script designed to automate the installation of Gentoo Linux on any modern x86_64 machine. It utilizes official pre-compiled Gentoo binary packages for rapid deployment and sets up an optimized Btrfs subvolume layout.

## 🚀 Features
- **Auto-Drive Detection:** Scans the hardware to identify whether it's an NVMe SSD or SATA HDD/SSD and layouts out a 512MB EFI + rest for `/` configuration.
- **Dynamic Networking:** Automatically checks for a LAN connection; drops down to an interactive Wi-Fi prompt (`nmtui`) if offline.
- **Btrfs Subvolumes:** Formats and mounts `@` (root) and `@home` configurations natively running transparent `zstd:3` compression.
- **Accelerated Binaries:** Leverages Gentoo's binhost infrastructure to install the Linux kernel, tools, and environments in minutes instead of hours.
- **Dynamic Configuration:** Prompts for your custom username and hostname at boot runtime.

## 🛠️ Usage Instructions

### Step 1: Boot into Gentoo LiveCD
Boot your target machine using the official [Gentoo LiveGUI or LiveCD Image](https://gentoo.org). 

### Step 2: Download the Scripts
Once you have an active terminal in the live environment, clone your repository or fetch the scripts directly:
```bash
git clone https://github.com
cd YOUR_REPO_NAME
chmod +x stage1.sh stage2.sh
```

### Step 3: Run Stage 1
Execute the first phase to partition your drive, download Stage 3, set up Btrfs subvolumes, and map your configurations:
```bash
./stage1.sh
```
Follow the interactive on-screen prompts to configure your network, **username**, and **hostname**.

### Step 4: Run Stage 2
Once Stage 1 finishes successfully, enter your new chroot environment and trigger the secondary deployment layer:
```bash
chroot /mnt/gentoo /bin/bash /root/stage2.sh
```

### Step 5: Reboot
Once completed, exit the environment, unmount clean, and reboot into your lightning-fast Gentoo installation:
```bash
exit
umount -R /mnt/gentoo
reboot
```
*Note: The default placeholder passwords for both `root` and your chosen user account are set to `gentoo`. Change them immediately upon first successful login using the `passwd` command.*
