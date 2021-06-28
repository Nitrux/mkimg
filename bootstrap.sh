#! /bin/bash

set -xe

export LANG=C
export LC_ALL=C

puts () { printf "\n\n --- %s\n" "$*"; }

#	Wrap APT commands in functions.

add_keys () { apt-key adv --keyserver keyserver.ubuntu.com --recv-keys $@; }
appstream_refresh_force () { appstreamcli refresh --force; }
autoremove () { apt -yy autoremove $@; }
clean_all () { apt clean && apt autoclean; }
dist_upgrade () { apt -yy dist-upgrade $@; }
dpkg_install () { dpkg -i $@; }
dpkg_force_install () { dpkg --force-all -i $@; }
dpkg_force_remove () { /usr/bin/dpkg --remove --no-triggers --force-remove-essential --force-bad-path $@; }
fix_install () { apt -yy --fix-broken install $@; }
hold () { apt-mark hold $@; }
install () { apt -yy install --no-install-recommends $@; }
install_downgrades () { apt -yy install --no-install-recommends --allow-downgrades $@; }
install_downgrades_hold () { apt -yy install --no-install-recommends --allow-downgrades --allow-change-held-packages $@; }
list_upgrade () { apt list --upgradable; }
only_upgrade () { apt -yy install --no-install-recommends --only-upgrade $@; }
pkg_policy () { apt-cache policy $@; }
purge () { apt -yy purge --remove $@; }
remove_keys () { apt-key del $@; }
unhold () { apt-mark unhold $@; }
update () { apt update; }
update_quiet () { apt -qq update; }
upgrade () { apt -yy upgrade $@; }
upgrade_downgrades () { apt -yy upgrade --allow-downgrades $@; }

puts "STARTING BOOTSTRAP."


#	Block installation of some packages.

cp /configs/files/preferences /etc/apt/preferences


#	Install basic packages.

puts "ADDING BASIC PACKAGES."

CHROOT_BASIC_PKGS='
	apt-transport-https
	apt-utils
	ca-certificates
	dhcpcd5
	gnupg2
	initramfs-tools
	lz4
'

update
upgrade
install $CHROOT_BASIC_PKGS


#	Add key for Nitrux repository.

puts "ADDING REPOSITORY KEYS."

add_keys \
	1B69B2DA > /dev/null


#	Copy repository sources.

puts "ADDING SOURCES FILES."

cp /configs/files/sources.list.nitrux /etc/apt/sources.list
cp /configs/files/sources.list.debian.experimental /etc/apt/sources.list.d/debian-experimental-repo.list
cp /configs/files/sources.list.debian.unstable /etc/apt/sources.list.d/debian-unstable-repo.list

update
dist_upgrade


#	Add bootloader.
#
#	The GRUB2 packages from Debian do not work correctly with EFI, so we use Ubuntu packages.

puts "ADDING BOOTLOADER."

add_keys \
	3B4FE6ACC0B21F32 \
	871920D1991BC93C > /dev/null

cp /configs/files/sources.list.impish /etc/apt/sources.list.d/ubuntu-impish-repo.list

update

GRUB2_PKGS='
	grub-common/impish
	grub-efi-amd64/impish
	grub-efi-amd64-bin/impish
	grub-efi-amd64-signed/impish
	grub-pc-bin/impish
	grub2-common/impish
	libfreetype6/unstable
'

install $GRUB2_PKGS

rm \
	/etc/apt/sources.list.d/ubuntu-impish-repo.list

remove_keys \
	3B4FE6ACC0B21F32 \
	871920D1991BC93C > /dev/null

update


#	Add eudev, elogind, and systemctl to replace systemd and utilize other inits.
#
#	To remove systemd, we have to replace libsystemd0, udev, elogind and provide systemctl. However, neither of them
#	are available to install from other sources than Devuan except for systemctl.

add_keys \
	541922FB \
	BB23C00C61FC752C > /dev/null

cp /configs/files/sources.list.devuan.beowulf /etc/apt/sources.list.d/devuan-beowulf-repo.list

update

puts "ADDING EUDEV AND ELOGIND."

DEVUAN_EUDEV_ELOGIND_PKGS='
	eudev
	elogind
'

REMOVE_SYSTEMD_PKGS='
	systemd
	systemd-sysv
	libsystemd0
'

SYSTEMCTL_STANDALONE_PKG='
	systemctl
'

install $DEVUAN_EUDEV_ELOGIND_PKGS
purge $REMOVE_SYSTEMD_PKGS
autoremove
install $SYSTEMCTL_STANDALONE_PKG

rm \
	/etc/apt/sources.list.d/devuan-beowulf-repo.list

remove_keys \
	541922FB \
	BB23C00C61FC752C > /dev/null

update


#	Add OpenRC as init.

puts "ADDING OPENRC AS INIT."

OPENRC_INIT_PKGS='
	initscripts
	init-system-helpers
	openrc
	policycoreutils
	startpar
	sysvinit-utils
'

install $OPENRC_INIT_PKGS


#	Add kernel.

puts "ADDING KERNEL."

MAINLINE_KERNEL_PKG='
	linux-image-mainline-lts
'

install $MAINLINE_KERNEL_PKG


#	Add Plymouth.
#
#	The version of Plymouth that is available from Debian requires systemd and udev.
#	To avoid this requirement, we will use the package from Devuan (chimaera) that only requires udev (eudev).

puts "ADDING PLYMOUTH."

add_keys \
	541922FB \
	BB23C00C61FC752C > /dev/null

cp /configs/files/sources.list.devuan.chimaera /etc/apt/sources.list.d/devuan-chimaera-repo.list

update

DEVUAN_PLYMOUTH_PKGS='
	plymouth/chimaera
	plymouth-label/chimaera
'

install $DEVUAN_PLYMOUTH_PKGS

rm \
	/etc/apt/sources.list.d/devuan-chimaera-repo.list

remove_keys \
	541922FB \
	BB23C00C61FC752C > /dev/null

update


#	Add casper.
#
#	It's worth noting that casper isn't available anywhere but Ubuntu.
#	Debian doesn't use it; it uses live-boot, live-config, et. al.

puts "ADDING CASPER."

add_keys \
	3B4FE6ACC0B21F32 \
	871920D1991BC93C > /dev/null

cp /configs/files/sources.list.impish /etc/apt/sources.list.d/ubuntu-impish-repo.list

update

CASPER_PKGS='
	casper
	lupin-casper
'

install $CASPER_PKGS

rm \
	/etc/apt/sources.list.d/ubuntu-impish-repo.list

remove_keys \
	3B4FE6ACC0B21F32 \
	871920D1991BC93C > /dev/null

update


#	Add misc. Ubuntu packages.
#
#	Some packages required by our meta-packages are only available in Ubuntu.
#
#	The rng-tools package is a transitional package for rng-tools5 in Debian; however, its init script
#	has a different name than the one we list in openrc-config, so we use the package from Ubuntu instead.

puts "ADDING UBUNTU MISC. PACKAGES."

add_keys \
	3B4FE6ACC0B21F32 \
	871920D1991BC93C > /dev/null

cp /configs/files/sources.list.impish /etc/apt/sources.list.d/ubuntu-impish-repo.list

update

MISC_UBUNTU_IMPISH_PKGS='
	linux-firmware
	linux-sound-base
	libc6-dev
	locales
	policykit-desktop-privileges
	rng-tools
	secureboot-db
	ssl-cert
	ubuntu-drivers-common
'

install $MISC_UBUNTU_IMPISH_PKGS

rm \
	/etc/apt/sources.list.d/ubuntu-impish-repo.list

cp /configs/files/sources.list.bionic /etc/apt/sources.list.d/ubuntu-bionic-repo.list

update

MISC_UBUNTU_BIONIC_PKGS='
	
'

install $MISC_UBUNTU_BIONIC_PKGS

rm \
	/etc/apt/sources.list.d/ubuntu-bionic-repo.list

remove_keys \
	3B4FE6ACC0B21F32 \
	871920D1991BC93C > /dev/null

update


#	Adding PolicyKit packages from Devuan.
#
#	Since we're using elogind to replace logind, we need to add the matching PolicyKit packages.
#
#	Strangely, the complete stack is only available in beowulf but not in ceres or chimaera.

puts "ADDING POLICYKIT ELOGIND COMPAT."

add_keys \
	541922FB \
	BB23C00C61FC752C > /dev/null

cp /configs/files/sources.list.devuan.beowulf /etc/apt/sources.list.d/devuan-beowulf-repo.list

update

DEVUAN_POLKIT_PKGS='
	libpolkit-agent-1-0/beowulf
	libpolkit-backend-1-0/beowulf
	libpolkit-backend-elogind-1-0/beowulf
	libpolkit-gobject-1-0/beowulf
	libpolkit-gobject-elogind-1-0/beowulf
	policykit-1/beowulf
'

install $DEVUAN_POLKIT_PKGS

rm \
	/etc/apt/sources.list.d/devuan-beowulf-repo.list

remove_keys \
	541922FB \
	BB23C00C61FC752C > /dev/null

update


#	Add misc. Devuan packages.
#
#	The network-manager package that is available in Debian does not have an init script compatible with OpenRC.
#	so we use the package from Devuan instead.
#
#	Devuan, like Debian, has both unstable and experimental suites, called ceres and chimaera. Prioritize installing
#	packages from chimaera over ceres, unless the package only exists in ceres.

puts "ADDING DEVUAN MISC. PACKAGES."

add_keys \
	541922FB \
	BB23C00C61FC752C > /dev/null

cp /configs/files/sources.list.devuan.chimaera /etc/apt/sources.list.d/devuan-chimaera-repo.list

update

MISC_DEVUAN_CHIMAERA_PKGS='
	network-manager
'

install $MISC_DEVUAN_CHIMAERA_PKGS

rm \
	/etc/apt/sources.list.d/devuan-chimaera-repo.list

remove_keys \
	541922FB \
	BB23C00C61FC752C > /dev/null

update


#	Add Nitrux meta-packages.

puts "ADDING NITRUX BASE."

NITRUX_BASE_PKGS='
	base-files=11.2.8+nitrux-legacy
	nitrux-hardware-drivers-legacy-minimal
	nitrux-minimal-legacy
	nitrux-standard-legacy
'

X11_BASE_PKGS='
	xserver-xorg-core
'

install $NITRUX_BASE_PKGS $X11_BASE_PKGS


#	Add Nvidia drivers or Nouveau.
#
#	The package nouveau-firmware isn't available in Debian but only in Ubuntu.
#
#	The Nvidia proprietary driver can't be installed alongside Nouveau.
#
#	To install it replace the Nouveau packages with the Nvidia counterparts.

puts "ADDING NVIDIA DRIVERS/NOUVEAU FIRMWARE."

add_keys \
	3B4FE6ACC0B21F32 \
	871920D1991BC93C > /dev/null

cp /configs/files/sources.list.impish /etc/apt/sources.list.d/ubuntu-impish-repo.list

update

NVIDIA_DRV_PKGS='
	xserver-xorg-video-nouveau
	nouveau-firmware
'

install $NVIDIA_DRV_PKGS

rm \
	/etc/apt/sources.list.d/ubuntu-impish-repo.list

remove_keys \
	3B4FE6ACC0B21F32 \
	871920D1991BC93C > /dev/null

update


#	Add NX Desktop meta-package.
#
#	Use MISC_DESKTOP_PKGS to add packages to test. If tests are positive, add to the appropriate meta-package.
#
#	Use the KDE Neon repository to provide the latest stable release of Plasma and KF5.

add_keys \
	55751E5D \
	3B4FE6ACC0B21F32 \
	871920D1991BC93C > /dev/null

cp /configs/files/sources.list.neon.user /etc/apt/sources.list.d/neon-user-repo.list
cp /configs/files/sources.list.focal /etc/apt/sources.list.d/ubuntu-focal-repo.list

update

puts "ADDING NX DESKTOP."

NX_DESKTOP_PKG='
	nx-desktop-legacy-minimal
'

MISC_DESKTOP_PKGS='
	appstream
	bluez
	cups-daemon
	dmz-cursor-theme
	i3
	i3status
	libkpmcore10
	libpython3.8
	libpython3.8-minimal
	libpython3.8-stdlib
	plymouth-theme-nitrux
	qml-module-qtquick-controls2
	qml-module-qtquick-layouts
	qml-module-qtquick-window2
	sddm
	xterm/unstable
'

install $NX_DESKTOP_PKG $MISC_DESKTOP_PKGS

rm \
	/etc/apt/sources.list.d/neon-user-repo.list \
	/etc/apt/sources.list.d/ubuntu-focal-repo.list

remove_keys \
	55751E5D \
	3B4FE6ACC0B21F32 \
	871920D1991BC93C > /dev/null

update


#	Add Calamares.
#
#	A problem with libkpmcore 20.12.3 causes Calamares to fail to copy the squashfs to 
#	the target device; instead, it copies it to tmpfs. We stick to the version of Calamares from Debian.

puts "ADDING CALAMARES INSTALLER."

CALAMARES_PKGS='
	calamares
	calamares-settings-nitrux
	squashfs-tools
	libqt5positioning5
	libqt5printsupport5
	libqt5sensors5
	libqt5webchannel5
'

install $CALAMARES_PKGS


#	Hold packages.
#
#	These packages are put on hold because they're known to be affected by the inexistence of Dash
#	as the default /bin/sh or their postinst scripts have bashisms.
#
#	See https://github.com/Nitrux/nitrux-bug-tracker/issues/15

HOLD_MISC_PKGS='
	base-passwd
	cgroupfs-mount
	ssl-cert
	systemctl
'

hold $HOLD_MISC_PKGS


#	Update Appstream cache.

clean_all
update
appstream_refresh_force


#	Remove sources used to build the root.

puts "REMOVE BUILD SOURCES."

rm \
	/etc/apt/preferences \
	/etc/apt/sources.list.d/debian-experimental-repo.list \
	/etc/apt/sources.list.d/debian-unstable-repo.list \
	/etc/apt/sources.list.d/devuan-beowulf-repo.list \
	/etc/apt/sources.list.d/devuan-ceres-repo.list \
	/etc/apt/sources.list.d/neon-user-repo.list \
	/etc/apt/sources.list.d/ubuntu-bionic-repo.list \
	/etc/apt/sources.list.d/ubuntu-focal-repo.list \
	/etc/apt/sources.list.d/ubuntu-impish-repo.list \
	/etc/apt/sources.list.d/ubuntu-xenial-repo.list || true

update


#	Add repository configuration.

puts "ADDING REPOSITORY SETTINGS."

NX_REPO_PKG='
	nitrux-repositories-config
'

install $NX_REPO_PKG


#	Add OpenRC configuration.
#
#	Due to how the upstream openrc package "works," we need to put this package at the end of the build process.
#	Otherwise, we end up with an unbootable system.
#
#	See https://github.com/Nitrux/openrc-config/issues/1

puts "ADDING OPENRC CONFIG."

OPENRC_CONFIG='
	openrc-config
'

install $OPENRC_CONFIG


#	WARNING:
#	No apt usage past this point.


#	Changes specific to this image. If they can be put in a package, do so.
#	FIXME: These fixes should be included in a package.

puts "ADDING MISC. FIXES."

cat /configs/files/grub > /etc/default/grub
cat /configs/files/casper.conf > /etc/casper.conf

ln -sv /usr/share/xsessions/i3.desktop /usr/share/xsessions/plasma.desktop 

rm \
	/boot/{vmlinuz,initrd.img,vmlinuz.old,initrd.img.old} || true

ln -svf /boot/vmlinuz-5.10.35-051035-generic /vmlinuz
ln -svf /boot/initrd.img-5.10.35-051035-generic /initrd.img

dpkg_force_remove dash || true

ln -svf /bin/bash /bin/sh

dpkg_force_remove dash


#	Use LZ4 compression when creating the initramfs.

puts "UPDATING THE INITRAMFS."

cp /configs/files/initramfs.conf /etc/initramfs-tools/

update-initramfs -u


#	List installed packages.

dpkg-query -l | less > installed_pkgs.txt
dpkg-query -f '${binary:Package}\n' -W | wc -l


#	WARNING:
#	No dpkg usage past this point.


#	Check contents of /boot.
#	Check contents of OpenRC runlevels.
#	Check links to kernel and initramdisk.
#	Check contents of init.d and sddm.conf.d.
#	Check the setuid and groups of /usr/lib/dbus-1.0/dbus-daemon-launch-helper
#	Check contents of /Applications
#	Check that init system is not systemd.
#	Check that /bin/sh is in fact not Dash.
#	Check existence and contents of casper.conf and sddm.conf
#	Check the contents of /etc/default/grub

puts "PERFORM MANUAL CHECKS."

ls -lh \
	/boot \
	/etc/runlevels/{default,nonetwork,off,recovery,sysinit} \
	/{vmlinuz,initrd.img} \
	/etc/{init.d,sddm.conf.d} \
	/usr/lib/dbus-1.0/dbus-daemon-launch-helper \
	/Applications || true

stat /sbin/init \
	/bin/sh

cat \
	/etc/{casper.conf,sddm.conf} \
	/etc/default/grub


puts "EXITING BOOTSTRAP."
