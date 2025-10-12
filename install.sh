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

# ----------------------------------------------
# 1️⃣  Jalankan Script Install Arch Desktop
# ----------------------------------------------
echo "Menjalankan setup Arch Desktop"
curl -fsSL https://raw.githubusercontent.com/x-inu/installarch/refs/heads/main/archdesktop.sh | sh

# ----------------------------------------------
# 3️⃣  Selesai
# ----------------------------------------------
echo -ne "
==============================================
|     SELESAI ARCHLINUX TELAH TERINSTALL     | 
==============================================
"
 
