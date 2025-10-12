#!/bin/bash

echo -ne "
==============================================
|       SCRIPT FULL INSTALL ARCH LINUX       | 
==============================================
"


# ----------------------------------------------
# 2️⃣  Jalankan Script Server Setup 
# ----------------------------------------------
echo
read -p "Apakah Anda ingin melanjutkan instalasi Arch Desktop (KDE Plasma)? (y/n): " desktop </dev/tty

while true; do
    if [ "$desktop" == "y" ]; then
        # ----------------------------------------------
        # 1️⃣  Jalankan Script Install Arch Desktop
        # ----------------------------------------------
        echo
        echo "Menjalankan setup Arch Desktop..."
        curl -fsSL https://raw.githubusercontent.com/x-inu/installarch/refs/heads/main/archdesktop.sh | sh
        break

    elif [ "$desktop" == "n" ]; then
        # ----------------------------------------------
        # 2️⃣  Selesai
        # ----------------------------------------------
        echo -ne "
==============================================
|     SELESAI — ARCH LINUX TELAH TERINSTALL   |
==============================================
"
        break

    else
        echo "Input tidak valid! Harap masukkan 'y' atau 'n'."
        read -p "> " desktop </dev/tty
    fi
done


 
