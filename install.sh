#!/bin/bash

BASE_URL="https://raw.githubusercontent.com/x-inu/installarch/refs/heads/main"

if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Script ini harus dijalankan sebagai root."
    exit 1
fi

run_remote() {
    local script="$1"
    local tmp
    tmp="$(mktemp)" || { echo "❌ Gagal membuat file sementara."; return 1; }

    if ! curl -fsSL "$BASE_URL/$script" -o "$tmp"; then
        echo "❌ Gagal mengunduh $script. Cek koneksi internet."
        rm -f "$tmp"
        return 1
    fi

    bash "$tmp"
    local rc=$?
    rm -f "$tmp"
    return $rc
}

while true; do
    clear
    echo "=============================================="
    echo "|       SCRIPT FULL INSTALL ARCH LINUX       |"
    echo "=============================================="
    echo
    echo "1) Install ArchServer  (base system + bootloader)"
    echo "2) Install ArchDesktop (KDE Plasma, tanpa SDDM)"
    echo "3) Keluar"
    echo
    read -p "Pilih nomor [1-3]: " choice </dev/tty
    case "$choice" in
        1)
            clear
            echo "Menjalankan script setup server..."
            echo
            if run_remote "archserver.sh"; then
                echo
                echo "=============================================="
                echo "|     SELESAI INSTALL ARCH SERVER            |"
                echo "=============================================="
            else
                echo
                echo "=============================================="
                echo "|     INSTALL ARCH SERVER GAGAL              |"
                echo "=============================================="
            fi
            read -p "Tekan Enter untuk kembali ke menu..." </dev/tty
            ;;
        2)
            clear
            echo "Menjalankan script setup desktop..."
            echo
            if run_remote "archdesktop.sh"; then
                echo
                echo "=============================================="
                echo "|     SELESAI INSTALL ARCH DESKTOP           |"
                echo "=============================================="
            else
                echo
                echo "=============================================="
                echo "|     INSTALL ARCH DESKTOP GAGAL             |"
                echo "=============================================="
            fi
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
            echo "Jangan lupa: umount -R /mnt && reboot"
            echo
            exit 0
            ;;
        *)
            echo "Pilihan tidak valid! Harap masukkan nomor 1, 2, atau 3."
            sleep 1
            ;;
    esac
done
