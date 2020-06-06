#! /bin/bash

set -x

export LANG=C
export LC_ALL=C

puts () { printf "\n\n --- %s\n" "$*"; }


#	let us start.

puts "STARTING BOOTSTRAP."


#	Install basic packages.

puts "INSTALLING BASIC PACKAGES."

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


#	Add key for Neon repository.

puts "ADDING REPOSITORY KEYS."

apt-key adv --keyserver keyserver.ubuntu.com --recv-keys \
	55751E5D > /dev/null


#	Use sources.list.build to build ISO.

cp /configs/files/sources.list /etc/apt/sources.list


#	Update packages list and install packages. Install desktop packages.

puts "INSTALLING DESKTOP PACKAGES."

DESKTOP_PACKAGES='
	neon-desktop
'

apt update &> /dev/null
apt -yy upgrade
apt -yy install ${DESKTOP_PACKAGES//\\n/ }


#	Install the kernel.

puts "INSTALL KERNEL."

INSTALL_KERNEL='
	linux-generic
'

apt -qq -o=Dpkg::Use-Pty=0 -yy install $INSTALL_KERNEL --no-install-recommends
apt -qq -o=Dpkg::Use-Pty=0 -yy autoremove
apt clean &> /dev/null
apt autoclean &> /dev/null


#	Make sure to refresh appstream cache.

appstreamcli refresh --force
apt update &> /dev/null


#	WARNING:
#	No apt usage past this point.

#	Changes specific to this image. If they can be put in a package, do so.
#	FIXME: These fixes should be included in a package.

puts "ADDING MISC. FIXES.

cp /configs/files/10-globally-managed-devices.conf /etc/NetworkManager/conf.d/


#	Update the initramfs.

printf "\n"
printf "UPDATE INITRAMFS."
printf "\n"

cp /configs/files/initramfs.conf /etc/initramfs-tools/
cat /configs/scripts/persistence >> /usr/share/initramfs-tools/scripts/casper-bottom/05mountpoints_lupin
# cp /configs/scripts/iso_scanner /usr/share/initramfs-tools/scripts/casper-premount/20iso_scan

update-initramfs -u


#	Clean the filesystem.

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
