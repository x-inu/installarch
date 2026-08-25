
# Install ArchLinux (Without SDDM)

Script instalasi Arch Linux otomatis, langsung ke KDE Plasma Wayland **tanpa SDDM** (tanpa lockscreen/display manager). Plasma dijalankan dari tty1.

## How to Use

Jalankan dari Arch Linux Live ISO sebagai root:

```bash
  curl -fsSL https://raw.githubusercontent.com/x-inu/installarch/refs/heads/main/install.sh | bash
```

> Gunakan `bash`, bukan `sh` — script memakai fitur bash (array, `[[ ]]`).

## Menu

| Opsi | Fungsi |
|---|---|
| 1 | **ArchServer** — partisi, base system, user, GRUB, NetworkManager, opsional OpenSSH |
| 2 | **ArchDesktop** — KDE Plasma + driver GPU + auto login + autostart Plasma Wayland |
| 3 | Keluar |

Urutan pemakaian normal: jalankan **1** dulu, lalu **2**, kemudian `umount -R /mnt && reboot`.

## Yang dilakukan ArchServer

- Cek root, Arch ISO, koneksi internet, mode boot (UEFI/BIOS)
- Mirror tercepat via `reflector` (sebelum `pacstrap`, jadi instalasi lebih cepat)
- Deteksi disk fisik saja (loop/cdrom/zram difilter)
- Partisi otomatis (ESP 1 GiB + root ext4) atau manual via `cfdisk`
- Penamaan partisi benar untuk SATA (`sda1`), NVMe (`nvme0n1p1`), dan eMMC (`mmcblk0p1`)
- Timezone otomatis dari IP, locale `en_US.UTF-8`, hostname + `/etc/hosts`
- Microcode CPU otomatis (`intel-ucode` / `amd-ucode`)
- Swap via `zram-generator`
- User baru di grup `wheel` + sudo, password root & user wajib diset
- GRUB (UEFI dengan fallback `BOOTX64.EFI`, atau BIOS)
- `multilib`, `ParallelDownloads`, dan `Color` diaktifkan di `pacman.conf`

## Yang dilakukan ArchDesktop

- Bisa dijalankan dari live ISO (otomatis masuk `arch-chroot`) atau langsung di sistem terpasang
- Driver GPU: AMD / Intel / NVIDIA / hybrid, dengan `nvidia_drm.modeset=1` + `mkinitcpio -P` untuk NVIDIA Wayland
- KDE Plasma + `polkit-kde-agent`, `xdg-user-dirs`, PipeWire, Bluetooth, font Noto (anti tofu)
- Opsional YAY (`yay-bin`, dibangun sebagai user biasa — bukan root)
- Auto login tty1 via `agetty` override
- Autostart `startplasma-wayland` di tty1 lewat `.bash_profile` (dengan `dbus-run-session`)

## Catatan

- Tanpa display manager: login lewat tty1, Plasma langsung jalan.
- Setelah memasang driver NVIDIA, **reboot wajib**.
- Partisi otomatis akan **menghapus seluruh isi disk** yang dipilih.
