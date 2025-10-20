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
echo "✅ Mode boot terdeteksi: $MODE"

# ============================
# CEK DISK YANG AKAN DIGUNAKAN
# ============================
while true; do
    echo
    echo "📦 Mendeteksi disk yang tersedia..."
    echo "----------------------------------------------"

    # Ambil daftar disk utama saja (bukan partisi)
    DISKS=($(lsblk -d -n -p -o NAME))
    SIZES=($(lsblk -d -n -p -o SIZE))

    # Jika tidak ada disk, keluar
    if [ ${#DISKS[@]} -eq 0 ]; then
        echo "❌ Tidak ada disk terdeteksi."
        exit 1
    fi

    # Tampilkan daftar
    for i in "${!DISKS[@]}"; do
        echo "  [$((i+1))] ${DISKS[$i]} (${SIZES[$i]})"
    done
    echo "----------------------------------------------"

    read -p "🖋️  Pilih nomor disk yang akan digunakan: " choice </dev/tty

    # Validasi input: harus angka dan dalam rentang
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#DISKS[@]} )); then
        DISK_PATH="${DISKS[$((choice-1))]}"
        echo -e "\n✅ Disk terpilih: $DISK_PATH"
        
        # Konfirmasi dengan validasi y/n
        while true; do
            read -p "⚠️  Semua data di $DISK_PATH akan dihapus. Lanjutkan? (y/n): " confirm </dev/tty
            case "$confirm" in
                y|Y)
                    echo "🔓 Melanjutkan instalasi..."
                    break 2  # Keluar dari dua loop: konfirmasi & pemilihan disk
                    ;;
                n|N)
                    echo "❌ Dibatalkan oleh pengguna."
                    exit 0
                    ;;
                *)
                    echo "❌ Input tidak valid! Harap masukkan 'y' atau 'n'."
                    ;;
            esac
        done
    else
        echo "❌ Pilihan tidak valid! Masukkan nomor yang sesuai dari daftar."
    fi
done


# ============================
# PEMBUATAN PARTISI (OTOMATIS / MANUAL)
# ============================
while true; do
    echo -e "\nMetode Pembuatan Partisi:"
    echo "  [1] Otomatis"
    echo "  [2] Manual (cfdisk)"
    read -p "Pilih opsi [1/2]: " PART_OPTION </dev/tty

    if [[ "$PART_OPTION" == "1" ]]; then
        echo -e "\n▶ Membuat partisi otomatis di $DISK_PATH..."
        sleep 1

        if [[ "$MODE" == "UEFI" ]]; then
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

    elif [[ "$PART_OPTION" == "2" ]]; then
        echo -e "\n▶ Membuka cfdisk..."
        echo "  - Gunakan 'dos' untuk BIOS atau 'gpt' untuk UEFI"
        echo "  - Buat dan simpan partisi, lalu keluar"
        sleep 2
        cfdisk "$DISK_PATH" </dev/tty

        echo -e "\n📂 Partisi setelah konfigurasi manual:"
        lsblk "$DISK_PATH"

        read -p "Masukkan partisi ROOT (contoh: ${DISK_PATH}1): " ROOT_PART </dev/tty

        if [[ "$MODE" == "UEFI" ]]; then
            read -p "Masukkan partisi EFI (contoh: ${DISK_PATH}2) [enter jika tidak ada]: " EFI_PART </dev/tty
        fi

    else
        echo -e "\n❌ Opsi tidak valid. Harap pilih 1 atau 2."
        continue
    fi

    # ============================
    # KONFIRMASI SEBELUM LANJUT
    # ============================
    while true; do
        echo -e "\n🧩 Partisi yang akan digunakan:"
        echo "  Root: $ROOT_PART"
        [[ "$MODE" == "UEFI" && -n "$EFI_PART" ]] && echo "  EFI : $EFI_PART"

        echo -e "\nLanjut ke instalasi?"
        echo "  [1] Ya, lanjut"
        echo "  [2] Tidak, ulang partisi"
        read -p "Pilih opsi [1/2]: " CONFIRM </dev/tty

        if [[ "$CONFIRM" == "1" ]]; then
            break 2  # Lanjut ke langkah berikutnya
        elif [[ "$CONFIRM" == "2" ]]; then
            echo -e "\n🔄 Mengulang proses partisi...\n"
            sleep 1
            clear
            break  # Ulang dari partisi
        else
            echo -e "\n❌ Opsi tidak valid. Harap pilih 1 atau 2."
        fi
    done
done

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
    pacman -Sy --noconfirm --needed reflector
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
    pacman -S --noconfirm --needed grub efibootmgr dosfstools mtools os-prober
    grub-install --removable --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    sed -i 's/^#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
    
else
    pacman -S --noconfirm --needed grub
    grub-install --target=i386-pc $DISK_PATH
fi

grub-mkconfig -o /boot/grub/grub.cfg

echo
echo "=============================================="
echo "  INSTALASI ARCH LINUX SELESAI!"
echo "=============================================="
