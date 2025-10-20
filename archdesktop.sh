#!/bin/bash

echo -ne "
==============================================
|        SCRIPT INSTALL ARCH DESKTOP         |  
==============================================
"
 
# Pastikan sudah di arch-chroot
if grep -q '/mnt ' /proc/mounts; then
    echo "📍 Belum berada di dalam arch-chroot. Memasuki chroot..."
    echo "▶ Menjalankan: arch-chroot /mnt /bin/bash"
    exec arch-chroot /mnt /bin/bash
else
    echo "✅ Deteksi: Anda sudah berada di dalam arch-chroot. Melanjutkan setup..."
fi


echo -ne "
==============================================
|              SETUP HOSTNAME                |
==============================================
"
read -p "Masukkan hostname (default: archlinux): " host </dev/tty
[ -z "$host" ] && host="archlinux"
echo "$host" > /etc/hostname
echo "Hostname diset ke: $host"
echo

echo -ne "
==============================================
|            SETUP PASSWORD ROOT             |
==============================================
"

while true; do
    read -p "Apakah Anda ingin mengatur password root sekarang? (y/n): " setroot </dev/tty

    if [ "$setroot" == "y" ]; then
        echo "Masukkan password untuk root:"
        passwd </dev/tty
        echo "Password root berhasil diatur."
        break
    elif [ "$setroot" == "n" ]; then
        echo "Password root dilewati (disarankan untuk diset manual nanti)."
        break
    else
        echo "Input tidak valid! Harap masukkan 'y' atau 'n'."
    fi
done

echo -ne "
==============================================
|             ADD NEW USER                   | 
==============================================
"

read -p "Masukkan nama user baru: " NEWUSER </dev/tty
[ -z "$NEWUSER" ] && { echo "Nama user tidak boleh kosong!"; exit 1; }

if id "$NEWUSER" &>/dev/null; then
    echo "User '$NEWUSER' sudah ada."
else
    useradd -m -G wheel -s /bin/bash "$NEWUSER"
    echo "Buat password untuk $NEWUSER:"
    passwd "$NEWUSER" </dev/tty
fi

pacman -Sy --noconfirm --needed sudo >/dev/null 2>&1
grep -q "^%wheel" /etc/sudoers || echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers

echo -e "\nUser '$NEWUSER' siap digunakan dengan akses sudo."

# ============================
# TANYA: Apakah ada OS lain?
# ============================
#echo
#read -p "Apakah ada OS lain (bootable lain)? (y/n): " bootable </dev/tty
#if [ "$bootable" == "y" ]; then
#    echo "Menjalankan instalasi GRUB..."
#    pacman -S --noconfirm grub efibootmgr dosfstools mtools os-prober
#
#    grub-install --removable --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
#    grub-mkconfig -o /boot/grub/grub.cfg
#
#    echo
#    echo "Silakan ubah konfigurasi grub..."
#    echo "Menghapus tanda # pada GRUB_DISABLE_OS_PROBER=false"
#    sed -i 's/^#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
#
#    grub-mkconfig -o /boot/grub/grub.cfg
#else
#    echo "Tidak ada bootable lain, lewati instalasi GRUB."
#fi

echo -ne "
==============================================
|        INSTALL ARCH DESKTOP KDE             |
==============================================
"

install_kde_tools() {
    echo
    echo "Memulai instalasi KDE Plasma dan aplikasi pendukung..."

    sudo pacman -S --noconfirm --needed \
    plasma-desktop plasma-workspace konsole kwalletmanager ark nano dolphin kate \
    networkmanager plasma-nm kde-gtk-config kwin kdecoration spectacle kscreen \
    plasma-systemmonitor plasma-pa kde-cli-tools xorg-xwayland xdg-desktop-portal \
    xdg-desktop-portal-kde pipewire pipewire-audio pipewire-pulse wireplumber linux-firmware

    echo "Instalasi tool KDE Plasma selesai."
}

install_amd_driver() {
    echo "Memasang driver AMD..."
    sudo pacman -S --noconfirm --needed mesa vulkan-radeon vulkan-icd-loader libva-mesa-driver
    echo "Driver AMD terpasang."
}

install_intel_driver() {
    echo "Memasang driver INTEL..."
    sudo pacman -S --noconfirm --needed mesa vulkan-intel vulkan-icd-loader libva-mesa-driver
    echo "Driver INTEL terpasang."
}

install_nvidia_driver() {
    echo "Memasang driver NVIDIA..."
    sudo pacman -S --noconfirm --needed nvidia nvidia-utils nvidia-settings
    echo "Driver NVIDIA terpasang."
}

install_all_drivers() {
    echo "Memasang semua driver VGA..."
    sudo pacman -S --noconfirm --needed \
    mesa vulkan-radeon vulkan-intel vulkan-icd-loader libva-mesa-driver \
    nvidia nvidia-utils nvidia-settings
    echo "Semua driver VGA terpasang."
}

echo
echo "Pilih driver VGA yang ingin diinstall:"
echo "  1) AMD Driver"
echo "  2) INTEL Driver"
echo "  3) NVIDIA Driver"
echo "  4) Install Semua Driver"

while true; do
    read -p "Masukkan pilihan [1-4]: " vga_choice </dev/tty
    case "$vga_choice" in
        1)
            install_amd_driver
            break
            ;;
        2)
            install_intel_driver
            break
            ;;
        3)
            install_nvidia_driver
            break
            ;;
        4)
            install_all_drivers
            break
            ;;
        *)
            echo "❌ Pilihan tidak valid! Masukkan angka 1-4."
            ;;
    esac
done

install_kde_tools

# ============================
# INSTALL YAY
# ============================
#echo -ne "
#==============================================
#|          INSTALL YAY (AUR HELPER)          |
#==============================================
#"

#read -p "Apakah Anda ingin menginstall YAY (AUR Helper)? (y/n): " install_yay </dev/tty

#if [ "$install_yay" == "y" ]; then
#    echo
#    echo "Memulai instalasi YAY..."
#    sudo pacman -S --needed --noconfirm git base-devel
#    git clone https://aur.archlinux.org/yay.git
#    cd yay
#    makepkg -si --noconfirm
#    cd ..
#    rm -rf yay
#    echo
#    echo "YAY berhasil diinstal."
#else
#    echo "Instalasi YAY dilewati."
#fi

echo -ne "
==============================================
|                 AUTO LOGIN                 |
==============================================
"
echo
while true; do
    read -p "Apakah ingin mengaktifkan auto login di tty1? (y/n): " autologin </dev/tty
    case "$autologin" in
        y|Y)
            read -p "Masukkan nama user untuk auto login: " username </dev/tty
            sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
            sudo tee /etc/systemd/system/getty@tty1.service.d/override.conf >/dev/null <<EOF
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin $username --noclear %I \$TERM
Type=simple
EOF
            sudo systemctl daemon-reexec
            sudo systemctl daemon-reload
            sudo systemctl restart getty@tty1
            echo "✅ Auto login berhasil diaktifkan untuk user: $username"
            break
            ;;
        n|N)
            echo "⚠️ Auto login dilewati."
            break
            ;;
        *)
            echo "❌ Input tidak valid! Masukkan 'y' atau 'n'."
            ;;
    esac
done

# ============================
# KONFIGURASI .bash_profile
# ============================
echo
echo "Menambahkan konfigurasi start Plasma otomatis..."

# Cari semua user yang punya direktori di /home
USER_LIST=($(ls /home 2>/dev/null))

if [ ${#USER_LIST[@]} -eq 0 ]; then
    echo "Tidak ditemukan direktori /home/<user>."
    echo "Menggunakan /root/.bash_profile sebagai default."
    TARGET_HOME="/root"
else
    if [ ${#USER_LIST[@]} -eq 1 ]; then
        TARGET_USER=${USER_LIST[0]}
        echo "Ditemukan user: $TARGET_USER"
    else
        echo "Ditemukan beberapa user di /home/:"
        i=1
        for u in "${USER_LIST[@]}"; do
            echo "  $i) $u"
            ((i++))
        done
        echo
        read -p "Pilih user untuk dikonfigurasi (masukkan angka): " pilihan </dev/tty
        TARGET_USER=${USER_LIST[$((pilihan-1))]}
    fi
    TARGET_HOME="/home/$TARGET_USER"
fi

BASH_PROFILE="$TARGET_HOME/.bash_profile"

# Buat file jika belum ada
if [ ! -f "$BASH_PROFILE" ]; then
    touch "$BASH_PROFILE"
    chown "$TARGET_USER:$TARGET_USER" "$BASH_PROFILE" 2>/dev/null
fi

# Tambahkan konfigurasi jika belum ada
if ! grep -q "startplasma-wayland" "$BASH_PROFILE" 2>/dev/null; then
    cat <<EOF >> "$BASH_PROFILE"

# Start Plasma Wayland otomatis di tty1
if [[ -z \$DISPLAY ]] && [[ \$(tty) = /dev/tty1 ]]; then
  exec startplasma-wayland
fi
EOF
    echo "Konfigurasi ditambahkan ke: $BASH_PROFILE"
else
    echo "Konfigurasi sudah ada di $BASH_PROFILE, dilewati."
fi

# ============================
# KONFIGURASI logind.conf
# ============================
echo
echo "Mengonfigurasi logind.conf..."
sudo sed -i 's/^#\?NAutoVTs=.*/NAutoVTs=1/' /etc/systemd/logind.conf
sudo sed -i 's/^#\?ReserveVT=.*/ReserveVT=0/' /etc/systemd/logind.conf

systemctl enable NetworkManager
systemctl restart NetworkManager

echo -ne "
==============================================
|     Instalasi dan konfigurasi selesai!     |
==============================================
"
