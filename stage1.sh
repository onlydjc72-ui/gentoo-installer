#!/usr/bin/env bash
# stage1.sh - LiveCD Setup with Network, User, Hostname & Drive Configuration
set -euo pipefail

# --- RUNTIME PARAMETER SELECTION ---
echo "==========================================="
echo "       GENTOO AUTOMATED SETUP INITIALIZER  "
echo "==========================================="
read -p "Enter the username for the new non-root account: " NEW_USER
if [[ -z "$NEW_USER" || ! "$NEW_USER" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
    echo "❌ Error: Invalid username."
    exit 1
fi

read -p "Enter the desired hostname for this computer: " HOSTNAME
if [[ -z "$HOSTNAME" || ! "$HOSTNAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]]; then
    echo "❌ Error: Invalid hostname. Use alpha-numeric characters, hyphens, or underscores."
    exit 1
fi
echo "✅ Configuration targets locked -> User: $NEW_USER | Hostname: $HOSTNAME"
echo "==========================================="

# --- AUTOMATIC DRIVE DETECTION ---
echo "==> Scanning system for available storage drives..."
AVAILABLE_DRIVES=$(lsblk -dno NAME,TYPE | awk '$2=="disk" {print "/dev/"$1}')

if [ -z "$AVAILABLE_DRIVES" ]; then
    echo "❌ Error: No valid storage drives found on this system."
    exit 1
fi

DRIVE=$(echo "$AVAILABLE_DRIVES" | head -n1)
echo "✅ Selected Target Drive: $DRIVE"

if [[ "$DRIVE" == *"nvme"* ]]; then
    BOOT_PART="${DRIVE}p1"
    ROOT_PART="${DRIVE}p2"
else
    BOOT_PART="${DRIVE}1"
    ROOT_PART="${DRIVE}2"
fi

# --- INTERNET CHECK & WI-FI FALLBACK ---
echo "==> Checking network connection..."
if ! ping -c 1 -W 2 google.com &> /dev/null; then
    echo "❌ No active internet connection found over LAN."
    echo "==> Attempting to launch interactive Wi-Fi configuration..."
    if command -v nmtui &> /dev/null; then
        nmtui
    elif command -v wpa_gui &> /dev/null; then
        echo "Please use wpa_gui or wpa_cli to connect to Wi-Fi, then restart this script."
        exit 1
    else
        echo "Error: No automated Wi-Fi tool found. Connect manually and re-run."
        exit 1
    fi
    if ! ping -c 1 -W 5 google.com &> /dev/null; then
        echo "❌ Network setup failed. Aborting installation."
        exit 1
    fi
fi
echo "✅ Internet connection verified."

# --- DYNAMIC STAGE 3 FETCHING ---
echo "==> Determining latest OpenRC Stage 3 tarball..."
MIRROR="https://gentoo.org"
LATEST_TXT=$(curl -s "${MIRROR}/latest-stage3-amd64-openrc.txt" | grep -v '^#' | awk '{print $1}' || true)
if [ -z "$LATEST_TXT" ]; then
    echo "❌ Failed to parse modern stage3 build."
    exit 1
fi
STAGE3_URL="${MIRROR}/${LATEST_TXT}"

echo "==> Partitioning $DRIVE (512MB EFI + Rest for Root)..."
sed -e 's/\s*#.*//' << EOF | fdisk "$DRIVE"
g        # Create GPT partition table
n        # New partition (EFI)
1        # Partition number 1
         # Default start sector
+512M    # 512MB Boot Partition
t        # Change type
1        # Select EFI system type
n        # New partition (Root)
2        # Partition number 2
         # Default start
         # Default end (rest of disk)
w        # Write changes
EOF

echo "==> Formatting partitions (EFI: VFAT | Root: BTRFS)..."
mkfs.vfat -F 32 "$BOOT_PART"
mkfs.btrfs -f "$ROOT_PART"

echo "==> Creating clean Btrfs Subvolume scheme..."
mkdir -p /mnt/btrfs_root
mount "$ROOT_PART" /mnt/btrfs_root
btrfs subvolume create /mnt/btrfs_root/@
btrfs subvolume create /mnt/btrfs_root/@home
umount /mnt/btrfs_root
rmdir /mnt/btrfs_root

echo "==> Mounting Btrfs Subvolumes with optimization flags..."
BTRFS_OPTS="noatime,compress=zstd:3,space_cache=v2"
mount -o "subvol=@,${BTRFS_OPTS}" "$ROOT_PART" /mnt/gentoo
mkdir -p /mnt/gentoo/home
mount -o "subvol=@home,${BTRFS_OPTS}" "$ROOT_PART" /mnt/gentoo/home

mkdir -p /mnt/gentoo/boot
mount "$BOOT_PART" /mnt/gentoo/boot

echo "==> Downloading and extracting Stage 3..."
cd /mnt/gentoo
wget "$STAGE3_URL"
tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner
rm stage3-*.tar.xz

echo "==> Copying DNS configurations..."
cp --dereference /etc/resolv.conf /mnt/gentoo/etc/

echo "==> Mounting necessary virtual filesystems..."
mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev
mount --bind /run /mnt/gentoo/run
mount --make-slave /mnt/gentoo/run

echo "==> Pre-configuring modern Binary Repositories before Chroot..."
mkdir -p /mnt/gentoo/etc/portage/binrepos.conf
cat << 'EOF' > /mnt/gentoo/etc/portage/binrepos.conf/gentoobinhost.conf
[gentoobinhost]
priority = 9999
sync-uri = https://gentoo.org
EOF

echo "==> Injecting selected targets into stage2 configurations..."
cat << EOF > /mnt/gentoo/root/stage2_vars.sh
export NEW_USER="$NEW_USER"
export HOSTNAME="$HOSTNAME"
EOF
cp stage2.sh /mnt/gentoo/root/stage2.sh
chmod +x /mnt/gentoo/root/stage2.sh

echo "==========================================="
echo "Stage 1 complete. Run the following command:"
echo "chroot /mnt/gentoo /bin/bash /root/stage2.sh"
echo "==========================================="
