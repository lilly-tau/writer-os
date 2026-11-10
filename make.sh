test -d ./build && rm -rf ./build

TEST=false
while getopts ":ti" OPT; do
	case $OPT in
	t)	TEST=true;;
	*)	echo "invalid option -$OPT";;
	esac
done

boot_LDFLAGS="-nmagic -static -nostdlib"

mkdir build
as --32 -o build/mbr.o src/mbr.s || exit 1
ld $boot_LDFLAGS -Tlinker/link-s1.ld -o build/mbr.elf build/mbr.o || exit 1
objcopy -O binary build/mbr.elf build/mbr.bin || exit 1
as --32 -o build/boot.o src/boot.s || exit 1
ld $boot_LDFLAGS -Tlinker/link-s1.ld -o build/boot.elf build/boot.o || exit 1
objcopy -O binary build/boot.elf build/boot.bin || exit 1


mkdir build/boot-part
as --32 -o build/boot-2.o src/boot-2.s || exit 1
ld $boot_LDFLAGS -Tlinker/link-s2.ld -o build/boot-2.elf build/boot-2.o\
	|| exit 1
objcopy -O binary build/boot-2.elf build/boot-part/BOOT

cp config/boot.mld build/boot-part/boot.mld
(
	cd build/boot-part
	tar -cf ../boot-part.tar *
)

# Create the filesystem.
dd if=/dev/zero of=build/writer.img bs=128M count=1 || exit 1
loopback=$(sudo losetup -f)
sudo losetup "$loopback" build/writer.img || exit 1
	# Partition how we like
	sudo parted "$loopback" mklabel msdos
	echo "Ignore\r" | sudo parted "$loopback" mkpart primary 0 16KiB
	echo "Ignore\r" | sudo parted "$loopback" set 1 boot on
	echo "Ignore\r" | sudo parted "$loopback" mkpart primary 16KiB 127MiB

	sudo fdisk -l "$loopback"
	sudo dd if=build/mbr.bin of="$loopback" bs=446 count=1 conv=notrunc
	sudo dd if=build/boot.bin of="$loopback"p1 bs=512 count=1 conv=notrunc
	sudo dd if=build/boot-part.tar of="$loopback"p1 bs=512 seek=1\
		conv=notrunc


sudo losetup -d "$loopback" || exit 1

if test "$TEST" = true; then
	qemu-system-i386 -drive file=build/writer.img,format=raw,rerror=report,werror=report
fi
