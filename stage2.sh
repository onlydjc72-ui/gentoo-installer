#!/usr/bin/env bash
# stage2.sh - Chroot Configuration (OpenRC + Binpkg + Custom Username & Hostname)
set -euo pipefail

echo "==> Sourcing profile and structural environment..."
source /etc/profile
export PS1="(chroot) $PS1"

if [ -f /root/stage2_vars.sh ]; then
    source /root/stage2_vars.sh
    rm /root/stage2_vars.sh
else
    echo "❌ Error: Dynamic configuration variables file missing. Aborting."
    exit 1
fi

echo "==> Configuring Hostname system rules..."
echo "hostname=\"$HOSTNAME\"" > /etc/conf.d/hostname

echo "==> Syncing Portage repositories..."
emerge-webrsync

echo "==> Configuring basic make.conf settings for Binpkgs..."
cat << 'EOF' >> /etc/portage/make.conf
COMMON_FLAGS="-O2 -pipe -march=x86-64"
CFLAGS="${COMMON_FLAGS}"
CXXFLAGS="${COMMON_FLAGS}"
FCFLAGS="${COMMON_FLAGS}"
FFLAGS="${COMMON_FLAGS}"
MAKEOPTS="-j$(nproc)"
USE="-systemd dbus networkmanager X dbus-wayland elogind"
ACCEPT_LICENSE="*"

# --- BINARY PACKAGE INSTRUCTIONS ---
FEATURES="getbinpkg"
EMERGE_DEFAULT_OPTS="${EMERGE_DEFAULT_OPTS} --getbinpkg=y --binpkg-respect-use=y"
EOF

echo "==> Configuring Timezone and Locales..."
echo "America/New_York" > /etc/timezone
emerge --config sys-libs/timezone-data

echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
eselect locale set 1
env-update && source /etc/profile

echo "==> Installing Pre-compiled Kernel and structural Btrfs tools..."
emerge sys-kernel/gentoo-kernel-bin sys-kernel/linux-firmware sys-fs/btrfs-progs

echo "==> Installing Bootloader (GRUB via Binpkg)..."
echo 'GRUB_PLATFORMS="efi-64"' >> /etc/portage/make.conf
emerge sys-boot/grub

BOOT_UUID=$(blkid -o value -s UUID $(df /boot | tail -n1 | awk '{print $1}'))
ROOT_UUID=$(blkid -o value -s UUID $(df / | tail -n1 | awk '{print $1}'))

echo "==> Constructing highly efficient Btrfs /etc/fstab structural mounts..."
cat << EOF > /etc/fstab
UUID=$BOOT_UUID /boot vfat defaults,noatime 0 2
UUID=$ROOT_UUID / btrfs subvol=@,noatime,compress=zstd:3,space_cache=v2 0 0
UUID=$ROOT_UUID /home btrfs subvol=@home,noatime,compress=zstd:3,space_cache=v2 0 0
EOF

echo "==> Deploying GRUB to EFI directory..."
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Gentoo
grub-mkconfig -o /boot/grub/grub.cfg

echo "==> Installing Modern Network Infrastructure & System Tools via Binpkg..."
emerge net-misc/networkmanager app-admin/sysklogd sys-process/cronie app-admin/sudo

rc-update add NetworkManager default
rc-update add sysklogd default
rc-update add cronie default

echo "==> Setting root password to default 'gentoo'..."
echo "root:gentoo" | chpasswd

echo "==> Creating non-root user account: $NEW_USER..."
useradd -m -G wheel,users,video,audio,portage -s /bin/bash "$NEW_USER"
echo "$NEW_USER:gentoo" | chpasswd

echo "==> Configuring sudo permissions for wheel group..."
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel

echo "=========================================================="
echo "Installation complete! Exit chroot, unmount, and reboot."
echo "Every package was configured via accelerated binaries."
echo "Your filesystem is compressed with zstd on subvolumes @ and @home."
echo "Default credentials for root and $NEW_USER are 'gentoo'."
echo "CHANGE THESE PASSWORDS IMPERATIVELY ON FIRST SUCCESSFUL BOOT."
echo "=========================================================="
