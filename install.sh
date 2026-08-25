#!/bin/bash

# Ref yang dipakai untuk mengunduh script pendukung.
# Pakai path /<ref>/ (bukan /refs/heads/<ref>/) karena cache CDN lebih cepat segar.
# Untuk memakai versi terkunci: INSTALLARCH_REF=<commit-sha> bash install.sh
INSTALLARCH_REF="${INSTALLARCH_REF:-main}"
BASE_URL="https://raw.githubusercontent.com/x-inu/installarch/${INSTALLARCH_REF}"

die() {
    echo
    echo "❌ ERROR: $*" >&2
    exit 1
}

[ "$(id -u)" -eq 0 ] || die "Script ini harus dijalankan sebagai root."

command -v curl >/dev/null 2>&1 || die "Perintah 'curl' tidak ditemukan."

# Script ini interaktif penuh. Tanpa tty, semua read gagal dan menu akan
# berputar tanpa henti, jadi lebih baik berhenti di awal.
if [ ! -e /dev/tty ] || ! : 2>/dev/null </dev/tty; then
    die "Tidak ada terminal (tty) yang tersedia. Jalankan script ini secara interaktif."
fi

TMPFILE=""
cleanup() { [ -n "$TMPFILE" ] && rm -f "$TMPFILE"; }
trap cleanup EXIT INT TERM

run_remote() {
    local script="$1" rc

    TMPFILE="$(mktemp)" || { echo "❌ Gagal membuat file sementara."; return 1; }

    # -H no-cache mengurangi peluang mendapat versi stale dari cache CDN
    if ! curl -fsSL -H 'Cache-Control: no-cache' "$BASE_URL/$script" -o "$TMPFILE"; then
        echo "❌ Gagal mengunduh $script. Cek koneksi internet."
        rm -f "$TMPFILE"; TMPFILE=""
        return 1
    fi

    if [ ! -s "$TMPFILE" ]; then
        echo "❌ File $script yang diunduh kosong."
        rm -f "$TMPFILE"; TMPFILE=""
        return 1
    fi

    bash "$TMPFILE"
    rc=$?

    rm -f "$TMPFILE"; TMPFILE=""
    return $rc
}

# Menu dijalankan sampai user memilih keluar. Bila read gagal (tty hilang di
# tengah jalan), keluar daripada berputar tanpa henti.
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
    [ "$INSTALLARCH_REF" != "main" ] && echo "  (ref terkunci: $INSTALLARCH_REF)" && echo

    if ! read -r -p "Pilih nomor [1-3]: " choice </dev/tty; then
        die "Input terputus (tty tidak tersedia)."
    fi

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
            read -r -p "Tekan Enter untuk kembali ke menu..." _ </dev/tty || die "Input terputus."
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
            read -r -p "Tekan Enter untuk kembali ke menu..." _ </dev/tty || die "Input terputus."
            ;;
        3)
            clear
            echo "Keluar..."
            echo
            echo "=============================================="
            echo "|     SELESAI ARCHLINUX TELAH TERINSTALL     |"
            echo "=============================================="
            echo
            if mountpoint -q /mnt 2>/dev/null; then
                echo "⚠️  /mnt masih ter-mount. Jalankan: umount -R /mnt && reboot"
            else
                echo "Jangan lupa reboot."
            fi
            echo
            exit 0
            ;;
        *)
            echo "Pilihan tidak valid! Harap masukkan nomor 1, 2, atau 3."
            sleep 1
            ;;
    esac
done
