#!/bin/bash
# ==============================================
# Arch Linux Auto Installer - by cubiespot
# ==============================================

echo "=============================================="
echo "     SCRIPT INSTALASI ARCH LINUX OTOMATIS      "
echo "=============================================="
echo

# ============================
# CEK SISTEM BERJALAN DI ARCH ISO
# ============================
if ! grep -q "Arch" /etc/os-release; then
    echo "Error: Script ini hanya bisa dijalankan di Arch Linux Live ISO!"
    exit 1
fi

# ============================
# CEK KONEKSI INTERNET
# ============================
echo
echo "Mengecek koneksi internet..."
if ! ping -c 1 archlinux.org &> /dev/null; then
    echo "Tidak ada koneksi internet. Pastikan bisa ping ke archlinux.org!"
    exit 1
else
    echo "Koneksi internet OK."
fi

# ============================
# CEK MODE BOOT (UEFI / BIOS)
# ============================
echo
if [ -d /sys/firmware/efi ]; then
    MODE="UEFI"
else
    MODE="BIOS"
fi
echo "Mode boot terdeteksi: $MODE"

# ============================
# CEK DISK YANG AKAN DIGUNAKAN
# ============================
echo
echo "Mendeteksi disk yang tersedia..."
echo "----------------------------------------------"

# Ambil daftar disk utama saja (bukan partisi)
DISKS=($(lsblk -d -n -p -o NAME,SIZE | awk '{print $1}'))
SIZES=($(lsblk -d -n -p -o NAME,SIZE | awk '{print $2}'))

# Tampilkan daftar
for i in "${!DISKS[@]}"; do
    echo "[$((i+1))] ${DISKS[$i]} (${SIZES[$i]})"
done

# Pilih disk
echo "----------------------------------------------"
read -p "Pilih nomor disk yang akan digunakan: " choice </dev/tty

# Validasi input
if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#DISKS[@]}" ]; then
    echo "Pilihan tidak valid!"
    exit 1
fi

DISK_PATH="${DISKS[$((choice-1))]}"

echo
echo "Disk terpilih: $DISK_PATH"
echo

# Konfirmasi sebelum hapus isi disk
read -p "Semua data di $DISK_PATH akan dihapus. Lanjutkan? (y/n): " confirm </dev/tty
if [ "$confirm" != "y" ]; then
    echo "Dibatalkan."
    exit 1
fi

# ============================
# PEMBUATAN PARTISI (OTOMATIS / MANUAL)
# ============================
echo
echo "Pilih metode pembuatan partisi:"
echo "1) Otomatis (dibuat oleh script)"
echo "2) Manual (buka cfdisk untuk konfigurasi sendiri)"
read -p "Pilih opsi [1/2]: " PART_OPTION </dev/tty

if [ "$PART_OPTION" == "2" ]; then
    echo
    echo "Membuka cfdisk untuk konfigurasi manual..."
    echo "Gunakan tipe 'dos' untuk BIOS / 'gpt' untuk UEFI, lalu buat partisi."
    echo "Tekan 'Write' untuk menyimpan lalu 'Quit'."
    echo
    sleep 2
    cfdisk "$DISK_PATH"
    echo
    echo "Selesai konfigurasi manual."
    lsblk "$DISK_PATH"
    echo
    read -p "Masukkan partisi root yang akan digunakan (contoh: ${DISK_PATH}1): " ROOT_PART </dev/tty

    # Jika mode UEFI, tawarkan mount partisi EFI juga
    if [ "$MODE" == "UEFI" ]; then
        read -p "Masukkan partisi EFI (contoh: ${DISK_PATH}2, atau kosongkan jika tidak ada): " EFI_PART </dev/tty
    fi
else
    echo
    echo "Membuat partisi otomatis di $DISK_PATH..."
    sleep 2

    if [ "$MODE" == "UEFI" ]; then
        parted -s "$DISK_PATH" mklabel gpt
        parted -s "$DISK_PATH" mkpart "EFI" fat32 1MiB 512MiB
        parted -s "$DISK_PATH" set 1 esp on
        parted -s "$DISK_PATH" mkpart "ROOT" ext4 512MiB 100%
        EFI_PART="${DISK_PATH}1"
        ROOT_PART="${DISK_PATH}2"
        mkfs.fat -F32 "$EFI_PART"
    else
        parted -s "$DISK_PATH" mklabel msdos
        parted -s "$DISK_PATH" mkpart primary ext4 1MiB 100%
        ROOT_PART="${DISK_PATH}1"
    fi
fi


# ============================
# FORMAT DAN MOUNT PARTISI
# ============================
echo
echo "Memformat dan memasang partisi..."
mkfs.ext4 "$ROOT_PART"
mount "$ROOT_PART" /mnt

if [ "$MODE" == "UEFI" ]; then
    mkdir -p /mnt/boot
    mount "$EFI_PART" /mnt/boot
fi

# ============================
# INSTALASI SISTEM DASAR
# ============================
echo
echo "Menginstal sistem dasar..."
timedatectl set-ntp true
pacman -Sy
pacman -S --noconfirm archlinux-keyring
pacstrap /mnt base linux linux-firmware nano --noconfirm

# ============================
# BUAT FSTAB
# ============================
echo
echo "Membuat file fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# ============================
# MASUK KE ARCH-CHROOT
# ============================
echo
echo "Masuk ke lingkungan chroot..."
arch-chroot /mnt /bin/bash <<EOF

# ============================
# KONFIGURASI DASAR
# ============================
# --- Deteksi dan Set Timezone Otomatis ---
echo "Mendeteksi timezone otomatis berdasarkan lokasi..."
time_zone="$(curl --fail https://ipapi.co/timezone)"
echo -ne "
System detected your timezone to be '$time_zone' 
"

if [ -n "$DETECTED_TZ" ]; then
    echo "Timezone terdeteksi: $time_zone"
    ln -sf "/usr/share/zoneinfo/$time_zone" /etc/localtime
else
    echo "Gagal mendeteksi timezone, menggunakan default: UTC"
    ln -sf /usr/share/zoneinfo/UTC /etc/localtime
fi

hwclock --systohc
echo

# --- Set Bahasa Default ke Inggris ---
echo "Mengatur locale ke default: en_US.UTF-8"
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen 2>/dev/null || echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
export LANG=en_US.UTF-8
echo

# ============================
# SETUP MIRROR TERVERCEPAT
# ============================
echo
echo "=============================================="
echo "     MENCARI DAN MENGATUR MIRROR TERVERCEPAT"
echo "=============================================="
echo

# Pastikan reflector terpasang
if ! pacman -Qi reflector &>/dev/null; then
    echo "Menginstal reflector..."
    pacman -Sy --noconfirm reflector
fi

# Backup mirrorlist lama
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak 2>/dev/null

# Gunakan reflector untuk memilih mirror tercepat dari server terdekat
echo "Mendeteksi dan mengatur mirror tercepat..."
reflector --country "$(curl -s https://ipapi.co/country_name)" \
  --protocol https \
  --sort rate \
  --latest 10 \
  --save /etc/pacman.d/mirrorlist

# Jika gagal, fallback ke mirror default global
if [ $? -ne 0 ]; then
    echo "Gagal mendeteksi mirror berdasarkan lokasi. Menggunakan default global..."
    reflector --latest 10 --sort rate --protocol https --save /etc/pacman.d/mirrorlist
fi

echo
echo "Mirror tercepat berhasil diatur:"
head -n 10 /etc/pacman.d/mirrorlist
echo

# ============================
# INSTALASI BOOTLOADER
# ============================
if [ "$MODE" = "UEFI" ]; then
    pacman -S --noconfirm grub efibootmgr dosfstools mtools os-prober
    grub-install --removable --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    sed -i 's/^#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
    
else
    pacman -S --noconfirm grub
    grub-install --target=i386-pc $DISK_PATH
fi

grub-mkconfig -o /boot/grub/grub.cfg

echo
echo "=============================================="
echo "  INSTALASI ARCH LINUX SELESAI!"
echo "=============================================="
