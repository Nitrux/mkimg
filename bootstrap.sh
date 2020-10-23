#! /bin/bash

set -xe

export LANG=C
export LC_ALL=C

puts () { printf "\n\n --- %s\n" "$*"; }


#	let us start.

puts "STARTING BOOTSTRAP."


#	Install basic packages.

puts "INSTALLING BASIC PACKAGES."

BASIC_PKGS='
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

apt -qq update
apt -qq -o=Dpkg::Use-Pty=0 -yy install $BASIC_PKGS --no-install-recommends


#	Add key for Neon repository.

puts "ADDING REPOSITORY KEYS."

apt-key adv --keyserver keyserver.ubuntu.com --recv-keys \
	55751E5D \
	3B4FE6ACC0B21F32 \
	871920D1991BC93C > /dev/null


#	Copy sources.list files.

puts "ADDING SOURCES FILES."

cp /configs/files/sources.list.neon.user /etc/apt/sources.list.d/neon-user-repo.list


#	Block installation of some packages.

cp /configs/files/preferences /etc/apt/preferences


#	Update packages list and install packages. Install desktop packages.

puts "INSTALLING DESKTOP PACKAGES."

DESKTOP_PACKAGES='
	neon-desktop
'

apt -qq update
apt -qq -o=Dpkg::Use-Pty=0 -yy upgrade
apt -qq -o=Dpkg::Use-Pty=0 -yy install $DESKTOP_PACKAGES


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
apt -qq update


#	WARNING:
#	No apt usage past this point.

#	Changes specific to this image. If they can be put in a package, do so.
#	FIXME: These fixes should be included in a package.

puts "ADDING MISC. FIXES."

cp /configs/files/10-globally-managed-devices.conf /etc/NetworkManager/conf.d/


#	Update the initramfs.


puts "UPDATING INITRAMFS."

cp /configs/files/initramfs.conf /etc/initramfs-tools/
cat /configs/scripts/persistence >> /usr/share/initramfs-tools/scripts/casper-bottom/05mountpoints_lupin
# cp /configs/scripts/iso_scanner /usr/share/initramfs-tools/scripts/casper-premount/20iso_scan

update-initramfs -u


#	Clean the filesystem.

puts "REMOVE CASPER."

REMOVE_CASPER='
casper
lupin-casper
'

/usr/bin/dpkg --remove --no-triggers --force-remove-essential --force-bad-path $REMOVE_CASPER


puts "EXITING BOOTSTRAP."
