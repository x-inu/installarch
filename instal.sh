#!/bin/bash

# ==============================================
#     SCRIPT INSTALL ARCH DESKTOP - CLEANED
# ==============================================

banner() {
    clear
    echo -e "
==============================================
|        SCRIPT INSTALL ARCH DESKTOP         |
=============================================="
}

section() {
    echo -e "
==============================================
|  $1
==============================================
"
}

# ------------------------------------------------------------
# CEK CHROOT
# ------------------------------------------------------------
check_chroot() {
    if grep -q '/mnt ' /proc/mounts; then
        echo "📍 Belum berada di dalam arch-chroot. Memasuki chroot..."
        echo "▶ Menjalankan: arch-chroot /mnt /bin/bash"
        exec arch-chroot /mnt /bin/bash
    else
        echo "✅ Deteksi: Anda sudah berada di dalam arch-chroot. Melanjutkan setup..."
    fi
}

# ------------------------------------------------------------
# SETUP HOSTNAME
# ------------------------------------------------------------
setup_hostname() {
    section "SETUP HOSTNAME"
    read -p "Masukkan hostname (default: archlinux): " host </dev/tty
    [ -z "$host" ] && host="archlinux"
    echo "$host" > /etc/hostname
    echo "Hostname diset ke: $host"
}

# ------------------------------------------------------------
# SETUP PASSWORD ROOT
# ------------------------------------------------------------
setup_root_password() {
    section "SETUP PASSWORD ROOT"
    while true; do
        read -p "Apakah Anda ingin mengatur password root sekarang? (y/n): " setroot </dev/tty
        case "$setroot" in
            y|Y)
                echo "Masukkan password untuk root:"
                passwd </dev/tty
                echo "✅ Password root berhasil diatur."
                break
                ;;
            n|N)
                echo "⚠️ Password root dilewati (disarankan diatur nanti)."
                break
                ;;
            *)
                echo "❌ Input tidak valid! Harap masukkan 'y' atau 'n'."
                ;;
        esac
    done
}

# ------------------------------------------------------------
# BUAT USER BARU
# ------------------------------------------------------------
create_user() {
    section "ADD NEW USER"
    read -p "Masukkan nama user baru: " NEWUSER </dev/tty
    [ -z "$NEWUSER" ] && { echo "❌ Nama user tidak boleh kosong!"; exit 1; }

    if id "$NEWUSER" &>/dev/null; then
        echo "User '$NEWUSER' sudah ada."
    else
        useradd -m -G wheel -s /bin/bash "$NEWUSER"
        echo "Buat password untuk $NEWUSER:"
        passwd "$NEWUSER" </dev/tty
    fi

    pacman -Sy --noconfirm --needed sudo >/dev/null 2>&1
    grep -q "^%wheel" /etc/sudoers || echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers
    echo "✅ User '$NEWUSER' siap digunakan dengan akses sudo."
}

# ------------------------------------------------------------
# INSTALASI DRIVER VGA
# ------------------------------------------------------------
install_amd_driver() {
    echo "🔧 Memasang driver AMD..."
    pacman -S --noconfirm --needed mesa vulkan-radeon vulkan-icd-loader libva-mesa-driver
}

install_intel_driver() {
    echo "🔧 Memasang driver INTEL..."
    pacman -S --noconfirm --needed mesa vulkan-intel vulkan-icd-loader libva-mesa-driver
}

install_nvidia_driver() {
    echo "🔧 Memasang driver NVIDIA..."
    pacman -S --noconfirm --needed nvidia nvidia-utils nvidia-settings
}

install_all_drivers() {
    echo "🔧 Memasang semua driver VGA..."
    pacman -S --noconfirm --needed \
        mesa vulkan-radeon vulkan-intel vulkan-icd-loader libva-mesa-driver \
        nvidia nvidia-utils nvidia-settings
}

choose_vga_driver() {
    section "INSTALL DRIVER VGA"
    echo "Pilih driver VGA yang ingin diinstall:"
    echo "  1) AMD"
    echo "  2) INTEL"
    echo "  3) NVIDIA"
    echo "  4) SEMUA DRIVER"

    while true; do
        read -p "Masukkan pilihan [1-4]: " vga_choice </dev/tty
        case "$vga_choice" in
            1) install_amd_driver; break ;;
            2) install_intel_driver; break ;;
            3) install_nvidia_driver; break ;;
            4) install_all_drivers; break ;;
            *) echo "❌ Pilihan tidak valid! Masukkan angka 1–4." ;;
        esac
    done
}

# ------------------------------------------------------------
# INSTALASI KDE DESKTOP
# ------------------------------------------------------------
install_kde_tools() {
    section "INSTALL ARCH DESKTOP KDE"
    echo "Memulai instalasi KDE Plasma dan tool pendukung..."
    pacman -S --noconfirm --needed \
        plasma-desktop plasma-workspace konsole kwalletmanager ark nano dolphin kate \
        networkmanager plasma-nm kde-gtk-config kwin kdecoration spectacle kscreen \
        plasma-systemmonitor plasma-pa kde-cli-tools xorg-xwayland xdg-desktop-portal \
        xdg-desktop-portal-kde pipewire pipewire-audio pipewire-pulse wireplumber linux-firmware
    echo "✅ Instalasi KDE Plasma selesai."
}

# ------------------------------------------------------------
# AUTO LOGIN
# ------------------------------------------------------------
setup_autologin() {
    section "AUTO LOGIN"
    while true; do
        read -p "Aktifkan auto login di tty1? (y/n): " autologin </dev/tty
        case "$autologin" in
            y|Y)
                read -p "Masukkan nama user untuk auto login: " username </dev/tty
                mkdir -p /etc/systemd/system/getty@tty1.service.d
                tee /etc/systemd/system/getty@tty1.service.d/override.conf >/dev/null <<EOF
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin $username --noclear %I \$TERM
Type=simple
EOF
                systemctl daemon-reexec
                systemctl daemon-reload
                systemctl restart getty@tty1
                echo "✅ Auto login diaktifkan untuk user: $username"
                break
                ;;
            n|N)
                echo "⚠️ Auto login dilewati."
                break
                ;;
            *)
                echo "❌ Input tidak valid!"
                ;;
        esac
    done
}

# ------------------------------------------------------------
# KONFIGURASI .bash_profile UNTUK START PLASMA
# ------------------------------------------------------------
setup_bash_profile() {
    section "CONFIGURASI START PLASMA"
    echo "Menambahkan autostart Plasma di .bash_profile..."

    USER_LIST=($(ls /home 2>/dev/null))
    if [ ${#USER_LIST[@]} -eq 0 ]; then
        TARGET_HOME="/root"
        echo "Tidak ada user di /home. Gunakan /root/.bash_profile"
    else
        if [ ${#USER_LIST[@]} -eq 1 ]; then
            TARGET_USER=${USER_LIST[0]}
        else
            echo "Pilih user untuk dikonfigurasi:"
            i=1; for u in "${USER_LIST[@]}"; do echo "  $i) $u"; ((i++)); done
            read -p "Masukkan angka: " pilihan </dev/tty
            TARGET_USER=${USER_LIST[$((pilihan-1))]}
        fi
        TARGET_HOME="/home/$TARGET_USER"
    fi

    BASH_PROFILE="$TARGET_HOME/.bash_profile"
    [ ! -f "$BASH_PROFILE" ] && touch "$BASH_PROFILE"

    if ! grep -q "startplasma-wayland" "$BASH_PROFILE" 2>/dev/null; then
        cat <<EOF >> "$BASH_PROFILE"

# Start Plasma Wayland otomatis di tty1
if [[ -z \$DISPLAY ]] && [[ \$(tty) = /dev/tty1 ]]; then
  exec startplasma-wayland
fi
EOF
        echo "✅ Konfigurasi ditambahkan ke $BASH_PROFILE"
    else
        echo "ℹ️ Konfigurasi sudah ada, dilewati."
    fi
}

# ------------------------------------------------------------
# KONFIGURASI logind.conf
# ------------------------------------------------------------
setup_logind() {
    section "KONFIGURASI LOGIND.CONF"
    sed -i 's/^#\?NAutoVTs=.*/NAutoVTs=1/' /etc/systemd/logind.conf
    sed -i 's/^#\?ReserveVT=.*/ReserveVT=0/' /etc/systemd/logind.conf
    systemctl enable NetworkManager
    systemctl restart NetworkManager
    echo "✅ logind.conf telah dikonfigurasi dan NetworkManager aktif."
}

# ------------------------------------------------------------
# MAIN EXECUTION FLOW
# ------------------------------------------------------------
banner
check_chroot
setup_hostname
setup_root_password
create_user
choose_vga_driver
install_kde_tools
setup_autologin
setup_bash_profile
setup_logind

section "INSTALASI DAN KONFIGURASI SELESAI!"
echo "✅ Arch Linux Desktop dengan KDE Plasma berhasil diinstal!"
