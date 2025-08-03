#!/bin/bash
set -e

mkfs.vfat -F 32 /dev/nvme0n1p1
mkfs.btrfs /dev/nvme0n1p2
mkswap /dev/nvme0n1p3
swapon /dev/nvme0n1p3

mkdir -p /mnt/gentoo
mount /dev/nvme0n1p2 /mnt/gentoo
mkdir -p /mnt/gentoo/boot/efi
mount /dev/nvme0n1p1 /mnt/gentoo/boot/efi

chronyd -q

cd /mnt/gentoo
wget https://distfiles.gentoo.org/releases/amd64/autobuilds/20250727T163903Z/stage3-amd64-desktop-systemd-20250727T163903Z.tar.xz

openssl dgst -r -sha512 stage3-amd64-desktop-systemd-20250727T163903Z.tar.xz
openssl dgst -r -blake2b512 stage3-amd64-desktop-systemd-20250727T163903Z.tar.xz
gpg --import /usr/share/openpgp-keys/gentoo-release.asc

tar xpvf stage3-amd64-desktop-systemd-20250727T163903Z.tar.xz --xattrs-include='*.*' --numeric-owner

cp --dereference /etc/resolv.conf /mnt/gentoo/etc/

mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev
mount --bind /run /mnt/gentoo/run
mount --make-slave /mnt/gentoo/run

chroot /mnt/gentoo /bin/bash <<'EOC'
set -e

source /etc/profile
export PS1="(chroot) ${PS1}"

cat > /etc/portage/make.conf <<EOF
COMMON_FLAGS="-march=znver2 -O2 -pipe"
CFLAGS="\${COMMON_FLAGS}"
CXXFLAGS="\${COMMON_FLAGS}"
FCFLAGS="\${COMMON_FLAGS}"
FFLAGS="\${COMMON_FLAGS}"
USE="X wayland bluetooth wifi udev systemd alsa pulseaudio dbus opengl gnome vulkan"
MAKEOPTS="-j12"
LANG="fr_FR.UTF-8"
LINGUAS="fr"
L10N="fr"
VIDEO_CARDS="amdgpu radeonsi"
INPUT_DEVICES="libinput keyboard mouse joystick"
EMERGE_DEFAULT_OPTS="--quiet-build=y"
PORTAGE_SCHEDULING_POLICY="idle"
ACCEPT_KEYWORDS="amd64"
CHOST="x86_64-pc-linux-gnu"
PORTAGE_TMPDIR="/var/tmp"
ACCEPT_LICENSE="*"
FEATURES="parallel-fetch ccache getbinpkg binpkg-request-signature"
CCACHE_SIZE="5G"
EOF

emerge-webrsync
emerge --ask --verbose --oneshot app-portage/mirrorselect
mirrorselect -s5 -D -o > /etc/portage/make.conf
emerge --sync
eselect news list
eselect news read
eselect profile set 6

mkdir -p /etc/portage/binrepos.conf
cat > /etc/portage/binrepos.conf/gentoobinhost.conf <<EOF
[binhost]
priority = 9999
sync-uri = https://distfiles.gentoo.org/releases/amd64/binpackages/23.0/x86-64-v3/
EOF

emerge --ask --oneshot app-portage/cpuid2cpuflags
echo "*/* $(cpuid2cpuflags)" > /etc/portage/package.use/00cpu-flags

emerge --ask --verbose --update --deep --newuse --getbinpkg @world
emerge --ask --depclean

ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
echo "fr_FR.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
eselect locale set $(eselect locale list | grep 'fr_FR.UTF-8' | awk '{print $1}')
cat > /etc/env.d/02locale <<EOF
LANG="fr_FR.UTF-8"
LC_COLLATE="C.UTF-8"
EOF
env-update && source /etc/profile
cat > /etc/locale.conf <<EOF
LANG=fr_FR.UTF-8
LC_COLLATE=C.UTF-8
EOF

emerge --ask sys-kernel/linux-firmware sys-firmware/sof-firmware
mkdir -p /etc/portage/package.use
echo "sys-apps/systemd boot" > /etc/portage/package.use/systemd
echo "sys-kernel/installkernel systemd-boot dracut" > /etc/portage/package.use/installkernel

emerge --ask sys-apps/systemd sys-kernel/installkernel

echo 'USE="${USE} dist-kernel"' >> /etc/portage/make.conf
emerge --ask sys-kernel/gentoo-kernel-bin
env-update && source /etc/profile
emerge --ask @module-rebuild
emerge --config sys-kernel/gentoo-kernel-bin

cat > /etc/fstab <<EOF
/dev/nvme0n1p2  /          btrfs   defaults,noatime,compress=zstd,space_cache=v2  0 1
/dev/nvme0n1p1  /boot/efi  vfat    defaults                                     0 2
/dev/nvme0n1p3  none       swap    sw                                           0 0
EOF

hostnamectl hostname acer-gentoo
emerge --ask net-misc/dhcpcd net-misc/networkmanager net-wireless/iw net-wireless/wpa_supplicant
systemctl enable --now dhcpcd NetworkManager.service

cat > /etc/hosts <<EOF
127.0.0.1     acer-gentoo.local acer-gentoo localhost
::1           acer-gentoo.local acer-gentoo localhost
EOF

echo "root:CHANGE_ME" | chpasswd

useradd -m -G wheel,audio,video,network -s /bin/bash mahe
echo "mahe:CHANGE_ME" | chpasswd

emerge --ask app-admin/sudo
sed -i '/^# %wheel ALL=(ALL) ALL/s/^# //' /etc/sudoers

systemd-machine-id-setup

emerge --ask app-shells/bash-completion net-misc/chrony sys-fs/btrfs-progs sys-block/io-scheduler-udev-rules
systemctl enable chronyd.service

bootctl install
bootctl list

echo "quiet splash" > /etc/kernel/cmdline

EOC

echo "Installation Gentoo completed."

