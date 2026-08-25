#!/bin/bash
# ==============================================
# Arch Linux KDE Desktop Setup (Without SDDM)
# ==============================================

INSTALLARCH_REF="${INSTALLARCH_REF:-main}"
DESKTOP_URL="https://raw.githubusercontent.com/x-inu/installarch/${INSTALLARCH_REF}/archdesktop.sh"

echo -ne "
==============================================
|        SCRIPT INSTALL ARCH DESKTOP         |
==============================================
"

die() {
    echo
    echo "❌ ERROR: $*" >&2
    exit 1
}

[ "$(id -u)" -eq 0 ] || die "Script ini harus dijalankan sebagai root."

# ============================
# MASUK KE CHROOT BILA MASIH DI LIVE ISO
# ============================
# Deteksi live ISO lewat penanda archiso, bukan sekadar cek /mnt. Tanpa ini,
# menjalankan menu desktop sebelum menu server akan memasang KDE ke RAM live
# ISO dan hilang saat reboot.
IS_LIVE_ISO="no"
if [ -d /run/archiso ] || grep -qs 'archisobasedir\|archisolabel' /proc/cmdline; then
    IS_LIVE_ISO="yes"
fi

if [ "$IS_LIVE_ISO" == "yes" ]; then
    if ! mountpoint -q /mnt 2>/dev/null || [ ! -d /mnt/etc ]; then
        echo "❌ Terdeteksi Arch Live ISO, tetapi tidak ada sistem terpasang di /mnt."
        echo
        echo "   Jalankan 'Install ArchServer' terlebih dahulu, atau mount manual:"
        echo "     mount /dev/<root-partition> /mnt"
        echo "     mount /dev/<efi-partition> /mnt/boot   # bila UEFI"
        exit 1
    fi

    echo "📍 Terdeteksi sistem terpasang di /mnt (masih di live ISO)."
    echo "▶ Menjalankan setup desktop di dalam arch-chroot..."
    echo

    # Salin script ini ke dalam chroot daripada mengunduh ulang: menghindari
    # ketergantungan curl di dalam chroot dan versi yang berbeda akibat cache CDN.
    SELF="${BASH_SOURCE[0]}"
    if [ -r "$SELF" ]; then
        cp "$SELF" /mnt/root/archdesktop-setup.sh || die "Gagal menyalin script ke /mnt."
        chmod +x /mnt/root/archdesktop-setup.sh
        arch-chroot /mnt /bin/bash /root/archdesktop-setup.sh
        RC=$?
        rm -f /mnt/root/archdesktop-setup.sh
        [ $RC -eq 0 ] || die "Setup desktop di dalam chroot gagal."
    else
        arch-chroot /mnt /bin/bash -c "curl -fsSL '$DESKTOP_URL' -o /root/ad.sh && bash /root/ad.sh; rc=\$?; rm -f /root/ad.sh; exit \$rc" \
            || die "Setup desktop di dalam chroot gagal."
    fi

    echo
    echo "=============================================="
    echo "|   SETUP DESKTOP SELESAI (dari live ISO)    |"
    echo "=============================================="
    echo "  Jalankan: umount -R /mnt && reboot"
    exit 0
fi

# Dari titik ini, kita berada di dalam chroot atau di sistem terpasang.
IN_CHROOT="no"
if [ "$(stat -c %d:%i / 2>/dev/null)" != "$(stat -c %d:%i /proc/1/root/. 2>/dev/null)" ]; then
    IN_CHROOT="yes"
fi
echo "✅ Menjalankan setup pada sistem terpasang (chroot: $IN_CHROOT)."

grep -q "Arch" /etc/os-release 2>/dev/null || die "Bukan sistem Arch Linux."

# ============================
# PILIH USER TARGET
# ============================
echo -ne "
==============================================
|               PILIH USER                   |
==============================================
"

USER_LIST=()
while IFS=: read -r uname _ uid _ _ uhome _; do
    if [ "$uid" -ge 1000 ] && [ "$uid" -lt 65534 ] && [ -d "$uhome" ]; then
        USER_LIST+=("$uname")
    fi
done < <(getent passwd)

if [ ${#USER_LIST[@]} -eq 0 ]; then
    echo "Tidak ada user biasa ditemukan. Membuat user baru."
    while true; do
        read -r -p "Masukkan nama user baru: " TARGET_USER </dev/tty
        if [[ "$TARGET_USER" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
            break
        fi
        echo "❌ Nama user tidak valid."
    done
    pacman -S --noconfirm --needed sudo >/dev/null 2>&1
    useradd -m -G wheel -s /bin/bash "$TARGET_USER" || die "Gagal membuat user."
    echo "Buat password untuk $TARGET_USER:"
    until passwd "$TARGET_USER" </dev/tty; do
        echo "⚠️  Gagal, coba lagi."
    done
    echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/10-wheel
    chmod 0440 /etc/sudoers.d/10-wheel
elif [ ${#USER_LIST[@]} -eq 1 ]; then
    TARGET_USER="${USER_LIST[0]}"
    echo "Ditemukan user: $TARGET_USER"
else
    echo "Ditemukan beberapa user:"
    for i in "${!USER_LIST[@]}"; do
        echo "  [$((i+1))] ${USER_LIST[$i]}"
    done
    echo
    while true; do
        read -r -p "Pilih user untuk dikonfigurasi [1-${#USER_LIST[@]}]: " pilihan </dev/tty
        if [[ "$pilihan" =~ ^[0-9]+$ ]] && (( pilihan >= 1 && pilihan <= ${#USER_LIST[@]} )); then
            TARGET_USER="${USER_LIST[$((pilihan-1))]}"
            break
        fi
        echo "❌ Pilihan tidak valid."
    done
fi

TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
[ -n "$TARGET_HOME" ] || die "Home directory user '$TARGET_USER' tidak ditemukan."
echo "Target user : $TARGET_USER ($TARGET_HOME)"

# ============================
# PILIH DRIVER VGA
# ============================
echo -ne "
==============================================
|              DRIVER VGA / GPU              |
==============================================
"

echo "GPU terdeteksi pada sistem:"
lspci 2>/dev/null | grep -Ei 'vga|3d|display' | sed 's/^/  /' || echo "  (tidak dapat mendeteksi)"
echo

install_amd_driver() {
    echo "Memasang driver AMD..."
    pacman -S --noconfirm --needed \
        mesa vulkan-radeon vulkan-icd-loader libva-mesa-driver mesa-vdpau \
        || die "Gagal memasang driver AMD."
    echo "✅ Driver AMD terpasang."
}

install_intel_driver() {
    echo "Memasang driver INTEL..."
    pacman -S --noconfirm --needed \
        mesa vulkan-intel vulkan-icd-loader intel-media-driver libva-intel-driver \
        || die "Gagal memasang driver Intel."
    echo "✅ Driver INTEL terpasang."
}

install_nvidia_driver() {
    echo "Memasang driver NVIDIA..."
    pacman -S --noconfirm --needed \
        nvidia-dkms nvidia-utils nvidia-settings libva-nvidia-driver linux-headers \
        || die "Gagal memasang driver NVIDIA."

    echo "Mengaktifkan nvidia_drm.modeset (wajib untuk Plasma Wayland)..."

    # KMS lewat kernel cmdline GRUB
    if [ -f /etc/default/grub ]; then
        if ! grep -q 'nvidia_drm.modeset=1' /etc/default/grub; then
            sed -i 's/^\(GRUB_CMDLINE_LINUX_DEFAULT="[^"]*\)"/\1 nvidia_drm.modeset=1 nvidia_drm.fbdev=1"/' /etc/default/grub
        fi
    fi

    # Muat modul lewat initramfs
    if [ -f /etc/mkinitcpio.conf ]; then
        if ! grep -q 'nvidia_drm' /etc/mkinitcpio.conf; then
            sed -i 's/^MODULES=(\(.*\))/MODULES=(\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
            sed -i 's/^MODULES=( /MODULES=(/' /etc/mkinitcpio.conf
        fi
        # kms hook bentrok dengan nvidia proprietary
        sed -i 's/\bkms\b //' /etc/mkinitcpio.conf
    fi

    NVIDIA_INSTALLED="yes"
    echo "✅ Driver NVIDIA terpasang."
}

echo "Pilih driver VGA yang ingin diinstall:"
echo "  [1] AMD"
echo "  [2] INTEL"
echo "  [3] NVIDIA"
echo "  [4] AMD + INTEL (mesa, tanpa NVIDIA)"
echo "  [5] Lewati / hanya mesa"
echo
echo "ℹ️  Jangan campur NVIDIA proprietary dengan driver lain kecuali memang laptop hybrid."

NVIDIA_INSTALLED="no"
while true; do
    read -r -p "Masukkan pilihan [1-5]: " vga_choice </dev/tty
    case "$vga_choice" in
        1) install_amd_driver; break ;;
        2) install_intel_driver; break ;;
        3) install_nvidia_driver; break ;;
        4) install_amd_driver; install_intel_driver; break ;;
        5)
            echo "Memasang mesa dasar..."
            pacman -S --noconfirm --needed mesa vulkan-icd-loader || die "Gagal memasang mesa."
            break
            ;;
        *) echo "❌ Pilihan tidak valid! Masukkan angka 1-5." ;;
    esac
done

# Laptop NVIDIA hybrid: tawarkan mesa pendamping
if [ "$NVIDIA_INSTALLED" == "yes" ]; then
    while true;do
        read -r -p "Ini laptop hybrid (Intel/AMD + NVIDIA)? (y/n): " hybrid </dev/tty
        case "$hybrid" in
            y|Y)
                pacman -S --noconfirm --needed mesa vulkan-icd-loader
                if lspci 2>/dev/null | grep -qi 'intel.*graphics'; then
                    pacman -S --noconfirm --needed vulkan-intel intel-media-driver
                fi
                if lspci 2>/dev/null | grep -qiE 'amd|radeon'; then
                    pacman -S --noconfirm --needed vulkan-radeon libva-mesa-driver
                fi
                break
                ;;
            n|N) break ;;
            *) echo "❌ Masukkan 'y' atau 'n'." ;;
        esac
    done
fi

# ============================
# INSTALL KDE PLASMA
# ============================
echo -ne "
==============================================
|       INSTALL KDE PLASMA (NO SDDM)         |
==============================================
"
echo
echo "Memulai instalasi KDE Plasma dan aplikasi pendukung..."

pacman -S --noconfirm --needed \
    plasma-desktop plasma-workspace kwin kdecoration kscreen \
    plasma-nm plasma-pa plasma-systemmonitor kde-cli-tools kde-gtk-config \
    breeze breeze-gtk kgamma polkit-kde-agent \
    konsole dolphin kate ark kwalletmanager spectacle kdeplasma-addons \
    xorg-xwayland xdg-desktop-portal xdg-desktop-portal-kde xdg-user-dirs \
    pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber \
    networkmanager bluez bluez-utils \
    noto-fonts noto-fonts-emoji noto-fonts-cjk ttf-dejavu ttf-liberation \
    power-profiles-daemon upower \
    || die "Instalasi KDE Plasma gagal."

echo "✅ Instalasi KDE Plasma selesai."

# ============================
# INSTALL YAY (AUR HELPER)
# ============================
echo -ne "
==============================================
|          INSTALL YAY (AUR HELPER)          |
==============================================
"
while true; do
    read -r -p "Install YAY (AUR Helper)? (y/n): " install_yay </dev/tty
    case "$install_yay" in
        y|Y)
            pacman -S --noconfirm --needed git base-devel || die "Gagal memasang git/base-devel."
            # makepkg tidak boleh dijalankan sebagai root
            BUILD_DIR="$TARGET_HOME/.cache/yay-build"
            rm -rf "$BUILD_DIR"
            install -d -o "$TARGET_USER" -g "$TARGET_USER" "$BUILD_DIR"

            echo "$TARGET_USER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/99-yay-temp
            chmod 0440 /etc/sudoers.d/99-yay-temp

            if sudo -u "$TARGET_USER" bash -c "
                cd '$BUILD_DIR' &&
                git clone --depth 1 https://aur.archlinux.org/yay-bin.git &&
                cd yay-bin &&
                makepkg -si --noconfirm
            "; then
                echo "✅ YAY berhasil diinstal."
            else
                echo "⚠️  Instalasi YAY gagal (bisa dicoba manual setelah reboot)."
            fi

            rm -f /etc/sudoers.d/99-yay-temp
            rm -rf "$BUILD_DIR"
            break
            ;;
        n|N)
            echo "Instalasi YAY dilewati."
            break
            ;;
        *) echo "❌ Masukkan 'y' atau 'n'." ;;
    esac
done

# ============================
# AUTO LOGIN TTY1
# ============================
echo -ne "
==============================================
|                 AUTO LOGIN                 |
==============================================
"
echo
AUTOLOGIN_USER=""
while true; do
    read -r -p "Aktifkan auto login di tty1 untuk '$TARGET_USER'? (y/n): " autologin </dev/tty
    case "$autologin" in
        y|Y)
            AUTOLOGIN_USER="$TARGET_USER"
            mkdir -p /etc/systemd/system/getty@tty1.service.d
            cat > /etc/systemd/system/getty@tty1.service.d/override.conf <<EOF
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin $AUTOLOGIN_USER --noclear %I \$TERM
Type=idle
EOF
            echo "✅ Auto login diaktifkan untuk user: $AUTOLOGIN_USER"
            break
            ;;
        n|N)
            echo "⚠️  Auto login dilewati."
            break
            ;;
        *) echo "❌ Input tidak valid! Masukkan 'y' atau 'n'." ;;
    esac
done

# ============================
# AUTOSTART PLASMA DI TTY1
# ============================
echo
echo "Menambahkan konfigurasi start Plasma otomatis..."

BASH_PROFILE="$TARGET_HOME/.bash_profile"
touch "$BASH_PROFILE"

if ! grep -q "startplasma-wayland" "$BASH_PROFILE" 2>/dev/null; then
    cat >> "$BASH_PROFILE" <<'EOF'

# Start Plasma Wayland otomatis di tty1
if [ -z "$WAYLAND_DISPLAY" ] && [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
  export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
  export QT_QPA_PLATFORM=wayland
  exec dbus-run-session startplasma-wayland
fi
EOF
    echo "✅ Konfigurasi ditambahkan ke: $BASH_PROFILE"
else
    echo "ℹ️  Konfigurasi sudah ada di $BASH_PROFILE, dilewati."
fi

chown "$TARGET_USER:$TARGET_USER" "$BASH_PROFILE" 2>/dev/null

# ============================
# KONFIGURASI logind.conf
# ============================
echo
echo "Mengonfigurasi logind.conf..."
if [ -f /etc/systemd/logind.conf ]; then
    sed -i 's/^#\?NAutoVTs=.*/NAutoVTs=2/' /etc/systemd/logind.conf
    sed -i 's/^#\?ReserveVT=.*/ReserveVT=0/' /etc/systemd/logind.conf
fi

# ============================
# AKTIFKAN SERVICE
# ============================
echo
echo "Mengaktifkan service..."
systemctl enable NetworkManager
systemctl enable bluetooth 2>/dev/null
systemctl enable power-profiles-daemon 2>/dev/null

# ============================
# REGENERATE INITRAMFS & GRUB
# ============================
if [ "$NVIDIA_INSTALLED" == "yes" ]; then
    echo
    echo "Regenerate initramfs (NVIDIA KMS)..."
    mkinitcpio -P || echo "⚠️  mkinitcpio gagal, periksa manual."

    if command -v grub-mkconfig >/dev/null 2>&1 && [ -d /boot/grub ]; then
        echo "Regenerate konfigurasi GRUB..."
        grub-mkconfig -o /boot/grub/grub.cfg || echo "⚠️  grub-mkconfig gagal, periksa manual."
    fi
fi

# Service restart hanya bermakna di sistem yang benar-benar berjalan
if [ "$IN_CHROOT" == "no" ]; then
    systemctl daemon-reload
    systemctl restart NetworkManager 2>/dev/null
fi

echo -ne "
==============================================
|     Instalasi dan konfigurasi selesai!     |
==============================================
"
echo
echo "  User desktop : $TARGET_USER"
[ -n "$AUTOLOGIN_USER" ] && echo "  Auto login   : aktif di tty1"
echo "  Session      : Plasma Wayland (tanpa SDDM)"
[ "$NVIDIA_INSTALLED" == "yes" ] && echo "  Catatan      : NVIDIA KMS aktif, WAJIB reboot"
echo
echo "  Reboot untuk masuk ke desktop."
echo
