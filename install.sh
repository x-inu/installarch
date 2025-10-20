#!/bin/bash

while true; do
    clear
    echo "=============================================="
    echo "|       SCRIPT FULL INSTALL ARCH LINUX       |"
    echo "=============================================="
    echo
    echo "1) Install ArchServer" 
    echo "2) Install ArchDesktop" 
    echo "3) Keluar"
    read -p "Pilih nomor [1-3]: " choice </dev/tty
    case "$choice" in
        1)
            clear
            echo "Menjalankan script setup server..."
            curl -fsSL https://raw.githubusercontent.com/x-inu/installarch/refs/heads/main/archserver.sh | bash
            echo
            echo "=============================================="
            echo "|     SELESAI INSTALL ARCH SERVER            |"
            echo "=============================================="
            last_choice="1"
            read -p "Tekan Enter untuk kembali ke menu..." </dev/tty
            ;;
        2)
            clear
            echo "Menjalankan script setup desktop..."
            curl -fsSL https://raw.githubusercontent.com/x-inu/installarch/refs/heads/main/archdesktop.sh | bash
            echo
            echo "=============================================="
            echo "|     SELESAI INSTALL ARCH DESKTOP           |"
            echo "=============================================="
            last_choice="2"
            read -p "Tekan Enter untuk kembali ke menu..." </dev/tty
            ;;
        3)
            clear
            echo "Keluar..."
            echo
            echo "=============================================="
            echo "|     SELESAI ARCHLINUX TELAH TERINSTALL     |"
            echo "=============================================="
            echo
            last_choice="3"
            exit 0
            ;;
        *)
            echo "Pilihan tidak valid! Harap masukkan nomor 1, 2, atau 3."
            sleep 1
            ;;
    esac
done
