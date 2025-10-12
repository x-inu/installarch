#!/bin/bash

echo "=============================================="
echo "       SCRIPT FULL INSTALL ARCH LINUX         "
echo "=============================================="
echo

# ----------------------------------------------
# 2️⃣  Jalankan Script Server Setup 
# ----------------------------------------------
echo
echo "Menjalankan script setup server"
curl -fsSL https://raw.githubusercontent.com/x-inu/installarch/refs/heads/main/archserver.sh | sh

# ----------------------------------------------
# 1️⃣  Jalankan Script Install Arch Desktop
# ----------------------------------------------
echo "Menjalankan setup Arch Desktop"
curl -fsSL https://raw.githubusercontent.com/x-inu/installarch/refs/heads/main/archdesktop.sh | sh

# ----------------------------------------------
# 3️⃣  Selesai
# ----------------------------------------------
echo
echo "=============================================="
echo "   SEMUA SCRIPT TELAH SELESAI DIJALANKAN!"
echo "=============================================="
 
