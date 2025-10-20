#!/bin/bash

clear
echo "=============================================="
echo "|       SCRIPT FULL INSTALL ARCH LINUX       |"
echo "=============================================="
echo

while true; do
    echo "1) Install ArchServer"
    echo "2) Install ArchDesktop"
    echo "3) Keluar"
    read -p "Pilih nomor [1-3]: " choice </dev/tty
    case "$choice" in
        1) echo "Menjalankan script setup server..."
           curl -fsSL raw.githubusercontent.com/x-inu/installarch/refs/heads/main/archserver.sh | sh
           break
           ;;
        2) echo "Menjalankan script setup desktop..."
           curl -fsSL raw.githubusercontent.com/x-inu/installarch/refs/heads/main/archdesktop.sh | sh
           break
           ;;
        3) echo "Keluar..."
           exit 0
           ;;
        *) echo "Pilihan tidak valid! Harap masukkan nomor 1, 2, atau 3."
           ;;
    esac
done


echo
echo "=============================================="
echo "|     SELESAI ARCHLINUX TELAH TERINSTALL     |"
echo "=============================================="
