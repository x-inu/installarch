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
echo "Menjalankan script setup server"
curl -fsSL https://raw.githubusercontent.com/x-inu/installarch/refs/heads/main/archserver.sh | sh


while true; do
    read -p "Apakah Anda ingin Menginstall Arch Desktop (y/n): " desktop </dev/tty
    if [ "$desktop" == "y" ]; then
        # ----------------------------------------------
        # 1️⃣  Jalankan Script Install Arch Desktop
        # ----------------------------------------------
        echo "Menjalankan setup Arch Desktop..."
        curl -fsSL https://raw.githubusercontent.com/x-inu/installarch/refs/heads/main/archdesktop.sh | sh
        break

    elif [ "$desktop" == "n" ]; then
        # ----------------------------------------------
        # 3️⃣  Selesai
        # ----------------------------------------------
        echo -ne "
   ==============================================
   |     SELESAI ARCHLINUX TELAH TERINSTALL     | 
   ==============================================
   "
        break

    else
        echo "Input tidak valid! Harap masukkan 'y' atau 'n'."
    fi
done
