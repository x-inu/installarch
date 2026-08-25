#!/bin/bash
# ==============================================
# Arch Linux Auto Installer - by cubiespot
# ==============================================

echo "=============================================="
echo "     SCRIPT INSTALASI ARCH LINUX OTOMATIS      "
echo "=============================================="
echo

die() {
    echo
    echo "❌ ERROR: $*" >&2
    exit 1
}

# ============================
# CEK DIJALANKAN SEBAGAI ROOT
# ============================
[ "$(id -u)" -eq 0 ] || die "Script ini harus dijalankan sebagai root."

# ============================
# CEK SISTEM BERJALAN DI ARCH ISO
# ============================
if ! grep -q "Arch" /etc/os-release; then
    die "Script ini hanya bisa dijalankan di Arch Linux Live ISO!"
fi

for tool in pacstrap arch-chroot genfstab parted lsblk; do
    command -v "$tool" >/dev/null 2>&1 || die "Perintah '$tool' tidak ditemukan. Jalankan dari Arch Live ISO."
done

# ============================
# CEK KONEKSI INTERNET
# ============================
echo
echo "Mengecek koneksi internet..."
if ! ping -c 1 -W 5 archlinux.org &> /dev/null; then
    die "Tidak ada koneksi internet. Pastikan bisa ping ke archlinux.org!"
fi
echo "Koneksi internet OK."

# ============================
# CEK MODE BOOT (UEFI / BIOS)
# ============================
echo
if [ -d /sys/firmware/efi/efivars ]; then
    MODE="UEFI"
else
    MODE="BIOS"
fi
echo "✅ Mode boot terdeteksi: $MODE"

# ============================
# HELPER PENAMAAN PARTISI
# ============================
# /dev/sda   -> /dev/sda1
# /dev/nvme0n1 -> /dev/nvme0n1p1
# /dev/mmcblk0 -> /dev/mmcblk0p1
part_name() {
    local disk="$1" num="$2"
    if [[ "$disk" =~ [0-9]$ ]]; then
        printf '%sp%s' "$disk" "$num"
    else
        printf '%s%s' "$disk" "$num"
    fi
}

# ============================
# SETUP MIRROR TERCEPAT (SEBELUM PACSTRAP)
# ============================
echo
echo "=============================================="
echo "     MENCARI DAN MENGATUR MIRROR TERCEPAT"
echo "=============================================="
echo

timedatectl set-ntp true >/dev/null 2>&1

mirrorlist_ok() {
    [ -s /etc/pacman.d/mirrorlist ] && grep -q '^Server' /etc/pacman.d/mirrorlist
}

if command -v reflector >/dev/null 2>&1; then
    cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak 2>/dev/null

    MIRROR_DONE="no"
    COUNTRY="$(curl -s --max-time 10 https://ipapi.co/country_name)"
    if [ -n "$COUNTRY" ]; then
        echo "Lokasi terdeteksi: $COUNTRY. Mencari mirror terdekat..."
        if reflector --country "$COUNTRY" --protocol https --sort rate --latest 10 \
            --save /etc/pacman.d/mirrorlist 2>/dev/null && mirrorlist_ok; then
            MIRROR_DONE="yes"
        fi
    fi

    if [ "$MIRROR_DONE" != "yes" ]; then
        echo "Fallback ke mirror global tercepat..."
        if ! { reflector --latest 20 --sort rate --protocol https \
                --save /etc/pacman.d/mirrorlist 2>/dev/null && mirrorlist_ok; }; then
            echo "⚠️  reflector gagal, memulihkan mirrorlist default ISO."
            cp /etc/pacman.d/mirrorlist.bak /etc/pacman.d/mirrorlist 2>/dev/null
        fi
    fi

    echo
    echo "Mirror aktif:"
    grep '^Server' /etc/pacman.d/mirrorlist | head -n 5
else
    echo "reflector tidak tersedia, menggunakan mirrorlist default ISO."
fi

# ============================
# DETEKSI TIMEZONE (SELAGI ADA JARINGAN)
# ============================
echo
TIME_ZONE="$(curl -s --fail --max-time 10 https://ipapi.co/timezone)"
if [ -n "$TIME_ZONE" ] && [ -f "/usr/share/zoneinfo/$TIME_ZONE" ]; then
    echo "🕒 Timezone terdeteksi: $TIME_ZONE"
else
    TIME_ZONE="UTC"
    echo "🕒 Gagal mendeteksi timezone, menggunakan default: UTC"
fi

# ============================
# CEK DISK YANG AKAN DIGUNAKAN
# ============================
while true; do
    echo
    echo "📦 Mendeteksi disk yang tersedia..."
    echo "----------------------------------------------"

    # Hanya disk fisik: buang loop (7), floppy (2), cdrom (11), zram (254)
    DISKS=()
    SIZES=()
    MODELS=()
    while read -r name size model; do
        DISKS+=("$name")
        SIZES+=("$size")
        MODELS+=("${model:-unknown}")
    done < <(lsblk -d -n -p -e 2,7,11,254 -o NAME,SIZE,MODEL 2>/dev/null)

    if [ ${#DISKS[@]} -eq 0 ]; then
        die "Tidak ada disk terdeteksi."
    fi

    for i in "${!DISKS[@]}"; do
        echo "  [$((i+1))] ${DISKS[$i]} (${SIZES[$i]}) - ${MODELS[$i]}"
    done
    echo "----------------------------------------------"
    echo "⚠️  Pastikan TIDAK memilih USB installer yang sedang dipakai."

    read -r -p "🖋️  Pilih nomor disk yang akan digunakan: " choice </dev/tty

    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#DISKS[@]} )); then
        DISK_PATH="${DISKS[$((choice-1))]}"
        echo -e "\n✅ Disk terpilih: $DISK_PATH"

        while true; do
            read -r -p "⚠️  Semua data di $DISK_PATH akan dihapus. Lanjutkan? (y/n): " confirm </dev/tty
            case "$confirm" in
                y|Y)
                    echo "🔓 Melanjutkan instalasi..."
                    break 2
                    ;;
                n|N)
                    echo "↩️  Kembali ke daftar disk..."
                    sleep 1
                    break
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

# Pastikan tidak ada partisi dari disk target yang masih ter-mount
umount -R /mnt 2>/dev/null
swapoff -a 2>/dev/null

# ============================
# PEMBUATAN PARTISI (OTOMATIS / MANUAL)
# ============================
EFI_PART=""
ROOT_PART=""

while true; do
    echo -e "\nMetode Pembuatan Partisi:"
    echo "  [1] Otomatis"
    echo "  [2] Manual (cfdisk)"
    read -r -p "Pilih opsi [1/2]: " PART_OPTION </dev/tty

    if [[ "$PART_OPTION" == "1" ]]; then
        echo -e "\n▶ Membuat partisi otomatis di $DISK_PATH..."
        sleep 1

        wipefs -a "$DISK_PATH" >/dev/null 2>&1

        if [[ "$MODE" == "UEFI" ]]; then
            parted -s "$DISK_PATH" mklabel gpt || die "Gagal membuat label GPT."
            parted -s "$DISK_PATH" mkpart "EFI" fat32 1MiB 1025MiB || die "Gagal membuat partisi EFI."
            parted -s "$DISK_PATH" set 1 esp on
            parted -s "$DISK_PATH" mkpart "ROOT" ext4 1025MiB 100% || die "Gagal membuat partisi root."
            EFI_PART="$(part_name "$DISK_PATH" 1)"
            ROOT_PART="$(part_name "$DISK_PATH" 2)"
        else
            parted -s "$DISK_PATH" mklabel msdos || die "Gagal membuat label MBR."
            parted -s "$DISK_PATH" mkpart primary ext4 1MiB 100% || die "Gagal membuat partisi root."
            parted -s "$DISK_PATH" set 1 boot on
            ROOT_PART="$(part_name "$DISK_PATH" 1)"
        fi

        partprobe "$DISK_PATH" >/dev/null 2>&1
        udevadm settle >/dev/null 2>&1
        sleep 2

    elif [[ "$PART_OPTION" == "2" ]]; then
        echo -e "\n▶ Membuka cfdisk..."
        echo "  - Gunakan 'dos' untuk BIOS atau 'gpt' untuk UEFI"
        echo "  - Buat dan simpan partisi, lalu keluar"
        sleep 2
        cfdisk "$DISK_PATH" </dev/tty

        partprobe "$DISK_PATH" >/dev/null 2>&1
        udevadm settle >/dev/null 2>&1

        echo -e "\n📂 Partisi setelah konfigurasi manual:"
        lsblk -p "$DISK_PATH"

        read -r -p "Masukkan partisi ROOT (contoh: $(part_name "$DISK_PATH" 1)): " ROOT_PART </dev/tty

        if [[ "$MODE" == "UEFI" ]]; then
            read -r -p "Masukkan partisi EFI (contoh: $(part_name "$DISK_PATH" 2)): " EFI_PART </dev/tty
        fi

    else
        echo -e "\n❌ Opsi tidak valid. Harap pilih 1 atau 2."
        continue
    fi

    # ============================
    # VALIDASI PARTISI
    # ============================
    if [ ! -b "$ROOT_PART" ]; then
        echo -e "\n❌ Partisi root '$ROOT_PART' tidak ditemukan. Ulangi."
        sleep 1
        continue
    fi

    if [[ "$MODE" == "UEFI" ]] && [ ! -b "$EFI_PART" ]; then
        echo -e "\n❌ Mode UEFI butuh partisi EFI yang valid. '$EFI_PART' tidak ditemukan. Ulangi."
        sleep 1
        continue
    fi

    # ============================
    # KONFIRMASI SEBELUM LANJUT
    # ============================
    while true; do
        echo -e "\n🧩 Partisi yang akan digunakan:"
        echo "  Root: $ROOT_PART"
        [[ "$MODE" == "UEFI" ]] && echo "  EFI : $EFI_PART"

        echo -e "\nLanjut ke instalasi?"
        echo "  [1] Ya, lanjut"
        echo "  [2] Tidak, ulang partisi"
        read -r -p "Pilih opsi [1/2]: " CONFIRM </dev/tty

        if [[ "$CONFIRM" == "1" ]]; then
            break 2
        elif [[ "$CONFIRM" == "2" ]]; then
            echo -e "\n🔄 Mengulang proses partisi...\n"
            sleep 1
            clear
            break
        else
            echo -e "\n❌ Opsi tidak valid. Harap pilih 1 atau 2."
        fi
    done
done

# ============================
# KONFIGURASI SISTEM (SEBELUM INSTALL)
# ============================
echo -ne "
==============================================
|              SETUP HOSTNAME                |
==============================================
"
read -r -p "Masukkan hostname (default: archlinux): " HOSTNAME_NEW </dev/tty
[ -z "$HOSTNAME_NEW" ] && HOSTNAME_NEW="archlinux"
# Validasi sesuai RFC 1123: huruf/angka/'-', maksimal 63 karakter.
# Tanpa ini, karakter seperti apostrof akan merusak /root/install.env saat di-source.
while ! [[ "$HOSTNAME_NEW" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]; do
    echo "❌ Hostname tidak valid (huruf, angka, dan '-' saja; maks 63 karakter)."
    read -r -p "Masukkan hostname (default: archlinux): " HOSTNAME_NEW </dev/tty
    [ -z "$HOSTNAME_NEW" ] && HOSTNAME_NEW="archlinux"
done
echo "Hostname: $HOSTNAME_NEW"

echo -ne "
==============================================
|                ADD NEW USER                |
==============================================
"
while true; do
    read -r -p "Masukkan nama user baru: " NEWUSER </dev/tty
    if [[ "$NEWUSER" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        break
    fi
    echo "❌ Nama user tidak valid (huruf kecil, angka, '-' dan '_', tidak boleh kosong)."
done

echo -ne "
==============================================
|             KEYMAP KEYBOARD                |
==============================================
"
CURRENT_KEYMAP="$(localectl status 2>/dev/null | sed -n 's/.*VC Keymap: *//p' | head -n1)"
case "$CURRENT_KEYMAP" in
    ""|"n/a"|"(unset)") CURRENT_KEYMAP="us" ;;
esac
echo "Contoh: us, uk, de, fr, es, it, br-abnt2, dvorak"
read -r -p "Masukkan keymap console (default: $CURRENT_KEYMAP): " KEYMAP </dev/tty
[ -z "$KEYMAP" ] && KEYMAP="$CURRENT_KEYMAP"
while ! [[ "$KEYMAP" =~ ^[a-zA-Z0-9._-]+$ ]]; do
    echo "❌ Keymap tidak valid."
    read -r -p "Masukkan keymap console (default: $CURRENT_KEYMAP): " KEYMAP </dev/tty
    [ -z "$KEYMAP" ] && KEYMAP="$CURRENT_KEYMAP"
done
echo "Keymap: $KEYMAP"

echo -ne "
==============================================
|                OPENSSH SERVER              |
==============================================
"
while true; do
    read -r -p "Install & aktifkan OpenSSH server? (y/n): " WANT_SSH </dev/tty
    case "$WANT_SSH" in
        y|Y) WANT_SSH="y"; break ;;
        n|N) WANT_SSH="n"; break ;;
        *) echo "❌ Masukkan 'y' atau 'n'." ;;
    esac
done

# ============================
# FORMAT DAN MOUNT PARTISI
# ============================
echo
echo "Memformat dan memasang partisi..."
mkfs.ext4 -F "$ROOT_PART" || die "Gagal memformat $ROOT_PART."
mount "$ROOT_PART" /mnt || die "Gagal mount $ROOT_PART ke /mnt."

if [ "$MODE" == "UEFI" ]; then
    # Format EFI hanya jika belum berisi filesystem FAT (agar dual-boot aman)
    if ! blkid -o value -s TYPE "$EFI_PART" 2>/dev/null | grep -qi vfat; then
        mkfs.fat -F32 "$EFI_PART" || die "Gagal memformat $EFI_PART."
    else
        echo "ℹ️  $EFI_PART sudah FAT32, tidak diformat ulang."
    fi
    mkdir -p /mnt/boot
    mount "$EFI_PART" /mnt/boot || die "Gagal mount $EFI_PART ke /mnt/boot."
fi

# ============================
# DETEKSI MICROCODE CPU
# ============================
UCODE=""
if grep -qi "GenuineIntel" /proc/cpuinfo; then
    UCODE="intel-ucode"
elif grep -qi "AuthenticAMD" /proc/cpuinfo; then
    UCODE="amd-ucode"
fi
[ -n "$UCODE" ] && echo "🔧 Microcode CPU: $UCODE"

# ============================
# INSTALASI SISTEM DASAR
# ============================
echo
echo "Menginstal sistem dasar (butuh waktu)..."

PKGS=(
    base base-devel linux linux-firmware
    nano vim sudo git
    networkmanager
    grub
    zram-generator
    reflector pacman-contrib
    man-db man-pages texinfo
    which usbutils pciutils
    zip unzip
)
[ -n "$UCODE" ] && PKGS+=("$UCODE")
[ "$WANT_SSH" == "y" ] && PKGS+=(openssh)

if [ "$MODE" == "UEFI" ]; then
    PKGS+=(efibootmgr dosfstools mtools os-prober)
fi

pacman -Sy --noconfirm >/dev/null
pacman -S --noconfirm --needed archlinux-keyring

pacstrap -K /mnt "${PKGS[@]}" || die "pacstrap gagal. Cek koneksi/mirror."

genfstab -U /mnt >> /mnt/etc/fstab || die "genfstab gagal."

# Batasi permission ESP agar tidak world-readable (genfstab memakai fmask/dmask=0022)
if [ "$MODE" == "UEFI" ]; then
    sed -i '/[[:space:]]\/boot[[:space:]]\+vfat[[:space:]]/{
        s/fmask=[0-7]*/fmask=0137/
        s/dmask=[0-7]*/dmask=0027/
    }' /mnt/etc/fstab
fi

# ============================
# SIAPKAN SCRIPT KONFIGURASI DI DALAM CHROOT
# ============================
echo
echo "Menyiapkan konfigurasi sistem..."

cat > /mnt/root/chroot-setup.sh <<'CHROOT_EOF'
#!/bin/bash
# Dijalankan di dalam arch-chroot. Variabel di-inject via /root/install.env
set -u
source /root/install.env

echo "▶ Konfigurasi timezone: $TIME_ZONE"
ln -sf "/usr/share/zoneinfo/$TIME_ZONE" /etc/localtime
hwclock --systohc

echo "▶ Konfigurasi locale: en_US.UTF-8"
sed -i 's/^#\(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen
grep -q '^en_US.UTF-8 UTF-8' /etc/locale.gen || echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo "▶ Konfigurasi keymap console: $KEYMAP"
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

echo "▶ Konfigurasi hostname: $HOSTNAME_NEW"
echo "$HOSTNAME_NEW" > /etc/hostname
cat > /etc/hosts <<HOSTS
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME_NEW.localdomain $HOSTNAME_NEW
HOSTS

echo "▶ Konfigurasi zram (swap)"
cat > /etc/systemd/zram-generator.conf <<ZRAM
[zram0]
zram-size = min(ram / 2, 4096)
compression-algorithm = zstd
ZRAM

echo "▶ Aktifkan multilib & parallel downloads"
sed -i 's/^#\(ParallelDownloads\)/\1/' /etc/pacman.conf
sed -i 's/^#\(Color\)/\1/' /etc/pacman.conf
sed -i '/^#\[multilib\]/,/^#Include = .*mirrorlist/ s/^#//' /etc/pacman.conf
pacman -Sy >/dev/null 2>&1

echo "▶ Regenerate initramfs"
mkinitcpio -P

echo "▶ Setup sudo untuk grup wheel"
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/10-wheel
chmod 0440 /etc/sudoers.d/10-wheel

echo "▶ Membuat user: $NEWUSER"
if id "$NEWUSER" &>/dev/null; then
    echo "  User '$NEWUSER' sudah ada."
else
    useradd -m -G wheel -s /bin/bash "$NEWUSER"
fi

echo
echo "=============================================="
echo "  Masukkan password untuk ROOT"
echo "=============================================="
until passwd root </dev/tty; do
    echo "⚠️  Password root gagal diset, coba lagi."
done

echo
echo "=============================================="
echo "  Masukkan password untuk user '$NEWUSER'"
echo "=============================================="
until passwd "$NEWUSER" </dev/tty; do
    echo "⚠️  Password user gagal diset, coba lagi."
done

echo "▶ Instalasi bootloader ($MODE)"
if [ "$MODE" = "UEFI" ]; then
    # sed hanya mengganti baris yang sudah ada, jadi tambahkan bila belum ada
    if grep -q '^#\?GRUB_DISABLE_OS_PROBER=' /etc/default/grub; then
        sed -i 's/^#\?GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
    else
        echo 'GRUB_DISABLE_OS_PROBER=false' >> /etc/default/grub
    fi
    if ! grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB; then
        echo "⚠️  grub-install standar gagal, mencoba mode --removable..."
        grub-install --removable --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB \
            || { echo "❌ grub-install gagal."; exit 1; }
    fi
    # Salinan fallback agar tetap boot bila NVRAM entry hilang
    mkdir -p /boot/EFI/BOOT
    cp -f /boot/EFI/GRUB/grubx64.efi /boot/EFI/BOOT/BOOTX64.EFI 2>/dev/null
else
    grub-install --target=i386-pc "$DISK_PATH" || { echo "❌ grub-install gagal."; exit 1; }
fi

grub-mkconfig -o /boot/grub/grub.cfg || { echo "❌ grub-mkconfig gagal."; exit 1; }

echo "▶ Mengaktifkan service"
systemctl enable NetworkManager
systemctl enable systemd-timesyncd
if [ "$WANT_SSH" = "y" ]; then
    systemctl enable sshd
    echo "  sshd diaktifkan (login root via SSH dinonaktifkan secara default)."
fi

echo
echo "✅ Konfigurasi dalam chroot selesai."
CHROOT_EOF

cat > /mnt/root/install.env <<ENV_EOF
TIME_ZONE=$(printf '%q' "$TIME_ZONE")
HOSTNAME_NEW=$(printf '%q' "$HOSTNAME_NEW")
NEWUSER=$(printf '%q' "$NEWUSER")
MODE=$(printf '%q' "$MODE")
DISK_PATH=$(printf '%q' "$DISK_PATH")
WANT_SSH=$(printf '%q' "$WANT_SSH")
KEYMAP=$(printf '%q' "$KEYMAP")
ENV_EOF

chmod 600 /mnt/root/install.env
chmod +x /mnt/root/chroot-setup.sh

# ============================
# MASUK KE ARCH-CHROOT
# ============================
echo
echo "Masuk ke lingkungan chroot..."
arch-chroot /mnt /bin/bash /root/chroot-setup.sh || die "Konfigurasi di dalam chroot gagal."

rm -f /mnt/root/chroot-setup.sh /mnt/root/install.env

echo
echo "=============================================="
echo "  INSTALASI ARCH LINUX SELESAI!"
echo "=============================================="
echo
echo "  Hostname : $HOSTNAME_NEW"
echo "  User     : $NEWUSER (grup wheel / sudo)"
echo "  Timezone : $TIME_ZONE"
echo "  Boot     : $MODE (GRUB)"
echo "  Root     : $ROOT_PART"
[ "$MODE" == "UEFI" ] && echo "  EFI      : $EFI_PART"
echo
echo "  Langkah selanjutnya:"
echo "   - Untuk install KDE Plasma, pilih menu 'Install ArchDesktop'"
echo "   - Atau langsung: umount -R /mnt && reboot"
echo
