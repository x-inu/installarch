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
echo "Menjalankan script setup server dari Chris Titus Tech..."
curl -fsSL https://raw.githubusercontent.com/ChrisTitusTech/linutil/main/core/tabs/system-setup/arch/server-setup.sh | sh

# ----------------------------------------------
# 1️⃣  Jalankan Script Install Arch Desktop
# ----------------------------------------------
echo "Menjalankan setup Arch Linux Cubiespot..."
curl -fsSL https://raw.githubusercontent.com/VikoFirdausi/installarch/refs/heads/main/arch.sh | sh

# ----------------------------------------------
# 3️⃣  Selesai
# ----------------------------------------------
echo
echo "=============================================="
echo "   SEMUA SCRIPT TELAH SELESAI DIJALANKAN!"
echo "=============================================="
