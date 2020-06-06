#! /bin/sh

#	Exit on errors.

set -e


#	base image URL.

base_img_url=http://cdimage.ubuntu.com/ubuntu-base/releases/18.04/release/ubuntu-base-18.04.4-base-amd64.tar.gz


#	WARNING:
#	Use sources.list.focal to update xorriso and GRUB.

wget -qO /etc/apt/sources.list https://raw.githubusercontent.com/Nitrux/nitrux-iso-tool/master/configs/files/sources.list.focal

XORRISO_PACKAGES='
	gcc-10-base
	grub-common
	grub-efi-amd64-bin
	grub-pc
	grub-pc-bin
	grub2-common
	libburn4
	libc-bin
	libc6
	libefiboot1
	libefivar1
	libgcc1
	libisoburn1
	libisofs6
	libjte1
	libreadline8
	libtinfo6
	locales
	readline-common
	xorriso
'

apt update &> /dev/null
apt -q -yy install $XORRISO_PACKAGES --no-install-recommends


#	Prepare the directories for the build.

build_dir=$(mktemp -d)
iso_dir=$(mktemp -d)
output_dir=$(mktemp -d)

config_dir=$PWD/configs


#	The name of the ISO image.

image=test_build_$(printf $TRAVIS_BRANCH | sed 's/master/stable/')-amd64.iso
update_url=http://repo.nxos.org:8000/${image%.iso}.zsync
hash_url=http://repo.nxos.org:8000/${image%.iso}.md5sum


#	Prepare the directory where the filesystem will be created.

wget -qO base.tar.gz $base_img_url
tar xf base.tar.gz -C $build_dir


#	Populate $build_dir.

wget -qO /bin/runch https://raw.githubusercontent.com/Nitrux/tools/master/runch
chmod +x /bin/runch

< bootstrap.sh runch \
	-m configs:/configs \
	-r /configs \
	$build_dir \
	bash || :


#	Copy the kernel and initramfs to $iso_dir.
#	BUG: vmlinuz and initrd are not moved to $iso_dir/; they're left at $build_dir/boot

mkdir -p $iso_dir/boot

cp $(echo $build_dir/boot/vmlinuz* | tr " " "\n" | sort | tail -n 1) $iso_dir/boot/kernel
cp $(echo $build_dir/boot/initrd*  | tr " " "\n" | sort | tail -n 1) $iso_dir/boot/initramfs

rm -f $build_dir/boot/*


#	WARNING FIXME BUG: This file isn't copied during the chroot.

mkdir -p $iso_dir/boot/grub/x86_64-efi
cp /usr/lib/grub/x86_64-efi/linuxefi.mod $iso_dir/boot/grub/x86_64-efi


#	Compress the root filesystem.

( while :; do sleep 300; printf ".\n"; done ) &

mkdir -p $iso_dir/casper
mksquashfs $build_dir $iso_dir/casper/filesystem.squashfs -comp gzip -no-progress -b 65536


#	Generate the ISO image.

wget -qO /bin/mkiso https://raw.githubusercontent.com/Nitrux/tools/master/mkiso
chmod +x /bin/mkiso
git clone https://github.com/UriHerrera/breeze-grub-theme grub-theme

mkiso \
	-V "Breeze" \
	-b \
	-e \
	-u "$update_url" \
	-s "$hash_url" \
	-r "${TRAVIS_COMMIT:0:7}" \
	-g $config_dir/files/grub.cfg \
	-g $config_dir/files/loopback.cfg \
	-t grub-theme/Breeze \
	$iso_dir $output_dir/$image


#	Calculate the checksum.

md5sum $output_dir/$image > $output_dir/${image%.iso}.md5sum


#	Generate the zsync file.

zsyncmake \
	$output_dir/$image \
	-u ${update_url%.zsync}.iso \
	-o $output_dir/${image%.iso}.zsync


#	Upload the ISO image.

for f in $output_dir/*; do
    SSHPASS=$DEPLOY_PASS sshpass -e scp -q -o stricthostkeychecking=no "$f" $DEPLOY_USER@$DEPLOY_HOST:$DEPLOY_PATH
done
