#!/bin/bash

clear
echo "=============================================="
echo "|       SCRIPT FULL INSTALL ARCH LINUX       |"
echo "=============================================="
echo

PS3=$'\n'"Silakan pilih jenis instalasi (ketik nomor): "

options=("Install ArchServer" "Install ArchDesktop" "Keluar")

select opt in "${options[@]}"
do
    case $REPLY in
        1)
            echo "Menjalankan script setup server..."
            curl -fsSL raw.githubusercontent.com/x-inu/installarch/refs/heads/main/archserver.sh | sh
            break
            ;;
        2)
            echo "Menjalankan script setup desktop..."
            curl -fsSL raw.githubusercontent.com/x-inu/installarch/refs/heads/main/archdesktop.sh | sh
            break
            ;;
        3)
            echo "Keluar..."
            exit 0
            ;;
        *)
            echo "Pilihan tidak valid! Harap masukkan nomor 1, 2, atau 3."
            ;;
    esac
done

echo
echo "=============================================="
echo "|     SELESAI ARCHLINUX TELAH TERINSTALL     |"
echo "=============================================="
