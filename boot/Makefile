# tools
NASM=nasm

# Flags for assembler
NASMFLAGS=-f bin

# all: builds MBR, stage 1 and stage 2 loader
all: mbr.bin stage1.bin stage2.bin

# build MBR loader
mbr.bin: mbr.asm
	$(NASM) $(NASMFLAGS) $^ -o out/$@ -l out/$(basename $@).lst

# build stage 1 loader
stage1.bin: stage1.asm
	$(NASM) $(NASMFLAGS) $^ -o out/$@ -l out/$(basename $@).lst

# build stage2 loader
stage2.bin: stage2.asm
	$(NASM) $(NASMFLAGS) $^ -o out/$@ -l out/$(basename $@).lst

# clean all the things
clean:
	rm out/mbr.bin
	rm out/stage1.bin
	rm out/stage2.bin
