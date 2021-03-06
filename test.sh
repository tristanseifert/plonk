#!/bin/sh
################################################################################
# Copies the bootloaders and the kernel to the image called "disk.img" and then
# opens qemu-x86.
#
# @note: Assumes that the the image has the first sector as the MBR, and the
# second sector immediately following is the first sector of the partition.
################################################################################

# Copy MBR bootloader
dd conv=notrunc if=boot/out/mbr.bin of=./disk.img count=446 bs=1

# Copy stage 1 header, then the code
dd conv=notrunc if=boot/out/stage1.bin of=./disk.img count=3 bs=1 seek=512
dd conv=notrunc if=boot/out/stage1.bin of=./disk.img count=448 bs=1 seek=616 skip=104

dd conv=notrunc if=boot/out/stage1.bin of=./disk.img count=3 bs=1 seek=$((512+3584))
dd conv=notrunc if=boot/out/stage1.bin of=./disk.img count=448 bs=1 seek=$((616+3584)) skip=104

# Copy stage 2 (at sector 2 of FAT)
dd conv=notrunc if=boot/out/stage2.bin of=./disk.img count=2560 bs=1 seek=1536
dd conv=notrunc if=boot/out/stage2.bin of=./disk.img count=2560 bs=1 seek=$((1536+3584))

# Launch qemu
qemu-system-i386 -hda disk.img -m 256M -vga std -soundhw sb16 -net nic,model=e1000 -net user -cpu pentium3 -rtc base=utc -monitor stdio -s