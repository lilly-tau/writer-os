#!/usr/bin/env sh

test -d ./build && rm -rf ./build

TEST=false
SHELL_DEBUG=false
while getopts ":tD" OPT; do
	case $OPT in
	t)	TEST=true;;
	D)	SHELL_DEBUG=true;;
	*)	echo "invalid option -$OPT";;
	esac
done

test "$SHELL_DEBUG" = true && set -x

boot_LDFLAGS="-nmagic -static -nostdlib"
boot_ASFLAGS="--32"

mkdir build

# CHS library (static, 16 bit)
as $boot_ASFLAGS -o build/chs.o src/chs.s || exit 1

# MBR
as $boot_ASFLAGS -o build/mbr.o src/mbr.s || exit 1
ld $boot_LDFLAGS -Tlinker/link-s1.ld -o build/mbr.elf build/mbr.o build/chs.o\
	|| exit 1
objcopy -O binary build/mbr.elf build/mbr.bin || exit 1

# Stage one bootloader
as $boot_ASFLAGS -o build/boot.o src/boot.s || exit 1
ld $boot_LDFLAGS -Tlinker/link-s1.ld -o build/boot.elf build/boot.o || exit 1
objcopy -O binary build/boot.elf build/boot.bin || exit 1


mkdir build/boot-part

# Stage two bootloader
as --32 --defsym FAST_A20=1 -o build/boot-2.o src/boot-2.s || exit 1
ld $boot_LDFLAGS -Tlinker/link-s2.ld -o build/boot-2.elf build/boot-2.o\
	|| exit 1
objcopy -O binary build/boot-2.elf build/boot-part/BOOT

# Create the boot filesystem tar
cp -r config/* build/boot-part/
(
	cd build/boot-part
	tar -cf ../boot-part.tar *
)

# Create the disk image
dd if=/dev/zero of=build/writer.img bs=128M count=1 || exit 1
loopback=$(sudo losetup -f)
sudo losetup "$loopback" build/writer.img || exit 1
	sudo parted "$loopback" mklabel msdos

	# Boot partition
	echo "Ignore\r" | sudo parted "$loopback" mkpart primary 0 16KiB
	echo "Ignore\r" | sudo parted "$loopback" set 1 boot on

	# Main partition
	echo "Ignore\r" | sudo parted "$loopback" mkpart primary 16KiB 127MiB

	sudo fdisk -l "$loopback"
	sudo dd if=build/mbr.bin of="$loopback" bs=446 count=1 conv=notrunc
	sudo dd if=build/boot.bin of="$loopback"p1 bs=512 count=1 conv=notrunc
	sudo dd if=build/boot-part.tar of="$loopback"p1 bs=512 seek=1\
		conv=notrunc

sudo losetup -d "$loopback" || exit 1

if test "$TEST" = true; then
	qemu-system-i386 -drive file=build/writer.img,format=raw
fi

test "$SHELL_DEBUG" = true && set +x
