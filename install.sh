#!/bin/bash
# ==============================================
# Arch Linux Full Setup - Cubiespot + Chris Titus
# ==============================================

echo "=============================================="
echo "   SCRIPT FULL INSTALL ARCH + KDE + SERVER     "
echo "=============================================="
echo

# ----------------------------------------------
# 2️⃣  Jalankan Script Server Setup dari Chris Titus Tech
# ----------------------------------------------
echo
echo "Menjalankan script setup server"
curl -fsSL /raw.githubusercontent.com/x-inu/installarch/refs/heads/main/archserver.sh | sh

# ----------------------------------------------
# 1️⃣  Jalankan Script Install Arch Desktop
# ----------------------------------------------
echo "Menjalankan setup Arch Desktop"
curl -fsSL raw.githubusercontent.com/x-inu/installarch/refs/heads/main/archdesktop.sh | sh

# ----------------------------------------------
# 3️⃣  Selesai
# ----------------------------------------------
echo
echo "=============================================="
echo "   SEMUA SCRIPT TELAH SELESAI DIJALANKAN!"
echo "=============================================="
 
