#!/bin/bash
# ==============================================
# Arch Linux Setup Script - by cubiespot
# Versi interaktif (bisa jalan via curl | sh)
# ==============================================

echo "=============================================="
echo "   SCRIPT INSTALL ARCH + KDE PLASMA AUTOMATIS  "
echo "=============================================="
echo
 
# Pastikan sudah di arch-chroot
if [ "$(ls / | grep mnt)" ]; then
    echo "Apakah Anda sudah berada di arch-chroot? (y/n)"
    read -p "> " chroot_answer </dev/tty
    if [ "$chroot_answer" != "y" ]; then
        echo "Masuk ke arch-chroot dulu..."
        echo "Menjalankan: arch-chroot /mnt /bin/bash"
        arch-chroot /mnt /bin/bash
        exit
    fi
fi

# ============================
# BUAT PASSWORD ROOT
# ============================
echo
echo "=============================================="
echo "   SETUP PASSWORD ROOT"
echo "=============================================="
echo
read -p "Apakah Anda ingin mengatur password root sekarang? (y/n): " setroot </dev/tty
if [ "$setroot" == "y" ]; then
    echo "Masukkan password untuk root:"
    passwd root
    echo "Password root berhasil diatur."
else
    echo "Password root dilewati (disarankan untuk diset manual nanti)."
fi

# ============================
# TANYA: Apakah ada OS lain?
# ============================
echo
read -p "Apakah ada OS lain (bootable lain)? (y/n): " bootable </dev/tty
if [ "$bootable" == "y" ]; then
    echo "Menjalankan instalasi GRUB..."
    pacman -S --noconfirm grub efibootmgr dosfstools mtools os-prober

    grub-install --removable --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    grub-mkconfig -o /boot/grub/grub.cfg

    echo
    echo "Silakan ubah konfigurasi grub..."
    echo "Menghapus tanda # pada GRUB_DISABLE_OS_PROBER=false"
    sed -i 's/^#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub

    grub-mkconfig -o /boot/grub/grub.cfg
else
    echo "Tidak ada bootable lain, lewati instalasi GRUB."
fi

# ============================
# INSTALL KDE PLASMA
# ============================
echo
echo "Memulai instalasi KDE Plasma..."
sudo pacman -S --noconfirm plasma-desktop plasma-workspace qt5-wayland qt6-wayland \
konsole kwalletmanager ark nano dolphin kate networkmanager plasma-nm kde-gtk-config \
kwin kdecoration spectacle kscreen plasma-systemmonitor plasma-pa kde-cli-tools \
xorg-xwayland xdg-desktop-portal xdg-desktop-portal-kde mesa lib32-mesa vulkan-radeon \
lib32-vulkan-radeon vulkan-icd-loader lib32-vulkan-icd-loader libva-mesa-driver \
lib32-libva-mesa-driver pipewire pipewire-audio pipewire-pulse wireplumber linux-firmware

# ============================
# AUTO LOGIN OPSIONAL
# ============================
echo
read -p "Apakah ingin mengaktifkan auto login di tty1? (y/n): " autologin </dev/tty
if [ "$autologin" == "y" ]; then
    read -p "Masukkan nama user untuk auto login: " username </dev/tty
    sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
    cat <<EOF | sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf >/dev/null
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin $username --noclear %I \$TERM
Type=simple
EOF

    sudo systemctl daemon-reexec
    sudo systemctl daemon-reload
    sudo systemctl restart getty@tty1
    echo "Auto login berhasil diaktifkan untuk user: $username"
else
    echo "Auto login dilewati."
fi

# ============================
# KONFIGURASI .bash_profile
# ============================
echo
echo "Menambahkan konfigurasi start Plasma otomatis..."
BASH_PROFILE="$HOME/.bash_profile"

if ! grep -q "startplasma-wayland" "$BASH_PROFILE" 2>/dev/null; then
    cat <<EOF >> "$BASH_PROFILE"

# Start Plasma Wayland otomatis di tty1
if [[ -z \$DISPLAY ]] && [[ \$(tty) = /dev/tty1 ]]; then
  exec startplasma-wayland
fi
EOF
fi

# ============================
# KONFIGURASI logind.conf
# ============================
echo
echo "Mengonfigurasi logind.conf..."
sudo sed -i 's/^#\?NAutoVTs=.*/NAutoVTs=1/' /etc/systemd/logind.conf
sudo sed -i 's/^#\?ReserveVT=.*/ReserveVT=0/' /etc/systemd/logind.conf

echo
echo "=============================================="
echo "   Instalasi dan konfigurasi selesai!"
echo "=============================================="
