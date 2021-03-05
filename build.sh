#! /bin/bash

#	Exit on errors.

set -xe


#	Travis stuff.

XORRISO_PKGS='
	libburn4
	libgcc1
	libisoburn1
	libisofs6
	libjte2
	mtools
	sshpass
	xorriso
'

GRUB_PKGS='
	grub-common
	grub-efi-amd64
	grub-efi-amd64-bin
	grub-efi-amd64-signed
	grub-pc-bin
	grub2-common
	shim-signed
'

apt -qq update
apt -qq -yy install $XORRISO_PKGS $GRUB_PKGS --no-install-recommends
pip3 install --upgrade python-gitlab


#	base image URL.

base_img_url=http://cdimage.ubuntu.com/ubuntu-base/releases/20.04/release/ubuntu-base-20.04.2-base-amd64.tar.gz


#	Prepare the directories for the build.

build_dir=$(mktemp -d)
iso_dir=$(mktemp -d)
output_dir=$(mktemp -d)

chmod 755 $build_dir

config_dir=$PWD/configs


#	The name of the ISO image.

image=nitrux-$(printf "$TRAVIS_BRANCH\n" | sed "s/legacy/release/")-amd64_$(date +%Y.%m.%d).iso
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


#	Check filesystem size.

du -hs $build_dir


#	Copy the kernel and initramfs to $iso_dir.
#	BUG: vmlinuz and initrd are not moved to $iso_dir/; they're left at $build_dir/boot

mkdir -p $iso_dir/boot

cp $(echo $build_dir/boot/vmlinuz* | tr " " "\n" | sort | tail -n 1) $iso_dir/boot/kernel
cp $(echo $build_dir/boot/initrd*  | tr " " "\n" | sort | tail -n 1) $iso_dir/boot/initramfs


#	WARNING FIXME BUG: This file isn't copied during the chroot.

mkdir -p $iso_dir/boot/grub/x86_64-efi
cp /usr/lib/grub/x86_64-efi/linuxefi.mod $iso_dir/boot/grub/x86_64-efi


#	Compress the root filesystem.

( while :; do sleep 300; printf ".\n"; done ) &

mkdir -p $iso_dir/casper
mksquashfs $build_dir $iso_dir/casper/filesystem.squashfs -comp zstd -no-progress -b 1048576


#	Generate the ISO image.

wget -qO /bin/mkiso https://raw.githubusercontent.com/Nitrux/tools/master/mkiso
chmod +x /bin/mkiso

git clone https://github.com/Nitrux/nitrux-grub-theme grub-theme

mkiso \
	-V "NITRUX" \
	-b \
	-e \
	-s "$hash_url" \
	-r "${TRAVIS_COMMIT:0:7}" \
	-g $config_dir/files/grub.cfg \
	-g $config_dir/files/loopback.cfg \
	-t grub-theme/nitrux \
	$iso_dir $output_dir/$image


#	Calculate the checksum.

md5sum $output_dir/$image > $output_dir/${image%.iso}.md5sum


#	Upload the ISO image.

for f in $output_dir/*; do
    SSHPASS=$DEPLOY_PASS sshpass -e scp -q -o stricthostkeychecking=no "$f" $DEPLOY_USER@$DEPLOY_HOST:$DEPLOY_PATH
done

