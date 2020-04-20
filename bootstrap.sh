#! /bin/bash

printf "\n"
printf "STARTING BOOTSTRAP."
printf "\n"

export LANG=C
export LC_ALL=C


# -- Install basic packages.

printf "\n"
printf "INSTALLING BASIC PACKAGES."
printf "\n"

BASIC_PACKAGES='
apt-transport-https
apt-utils
ca-certificates
casper
cifs-utils
dhcpcd5
fuse
gnupg2
inetutils-ping
language-pack-en
language-pack-en-base
localechooser-data
locales
lupin-casper
packagekit
phonon4qt5
phonon4qt5-backend-vlc
policykit-1
sudo
user-setup
wget
xz-utils
'

apt update &> /dev/null
apt -yy install ${BASIC_PACKAGES//\\n/ } --no-install-recommends


# -- Add key for KDE Neon repositories

printf "\n"
printf "ADD REPOSITORY KEYS."
printf "\n"

wget -q https://archive.neon.kde.org/public.key -O neon.key
	printf "ee86878b3be00f5c99da50974ee7c5141a163d0e00fccb889398f1a33e112584 neon.key" | sha256sum -c &&
	apt-key add neon.key > /dev/null
	rm neon.key


# -- Use sources.list.build to build ISO.

cp /configs/files/sources.list /etc/apt/sources.list


# -- Update packages list and install packages. Install desktop packages.

printf "\n"
printf "INSTALLING DESKTOP."
printf "\n"

DESKTOP_PACKAGES='
neon-desktop
'

apt update &> /dev/null
apt -yy upgrade
apt -yy install ${DESKTOP_PACKAGES//\\n/ }
apt clean &> /dev/null
apt autoclean &> /dev/null


# -- Install the kernel.

printf "\n"
printf "INSTALLING KERNEL."
printf "\n"

kfiles='
https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.6.5/linux-headers-5.6.5-050605_5.6.5-050605.202004171629_all.deb
https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.6.5/linux-headers-5.6.5-050605-generic_5.6.5-050605.202004171629_amd64.deb
https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.6.5/linux-image-unsigned-5.6.5-050605-generic_5.6.5-050605.202004171629_amd64.deb
https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.6.5/linux-modules-5.6.5-050605-generic_5.6.5-050605.202004171629_amd64.deb
'

mkdir latest_kernel

for x in $kfiles; do
	printf "$x"
	wget -q -P latest_kernel $x
done

dpkg -iR latest_kernel &> /dev/null
rm -r latest_kernel


# -- Add fix for https://bugs.launchpad.net/ubuntu/+source/network-manager/+bug/1638842.

printf "\n"
printf "ADD MISC. FIXES."
printf "\n"

cp /configs/files/10-globally-managed-devices.conf /etc/NetworkManager/conf.d/


# -- Update the initramfs.

printf "\n"
printf "UPDATE INITRAMFS."
printf "\n"

cp /configs/files/initramfs.conf /etc/initramfs-tools/
cat /configs/scripts/persistence >> /usr/share/initramfs-tools/scripts/casper-bottom/05mountpoints_lupin
# cp /configs/scripts/iso_scanner /usr/share/initramfs-tools/scripts/casper-premount/20iso_scan

update-initramfs -u


# -- Clean the filesystem.

printf "\n"
printf "REMOVE CASPER."
printf "\n"

REMOVE_PACKAGES='
casper
lupin-casper
'

/usr/bin/dpkg --remove --no-triggers --force-remove-essential --force-bad-path ${REMOVE_PACKAGES//\\n/ }


printf "\n"
printf "EXITING BOOTSTRAP."
printf "\n"
