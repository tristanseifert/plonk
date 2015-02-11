;===============================================================================
; The Plonk Bootloader
;
; Stage 2 loader: Provides an interface for booting operating systems. Loaded by
; stage 1.
;
; This is loaded to 0x0000:0x8000. This has the advantage of DS being zero,
; meaning we can use Unreal Mode.
;
; If access to the MBR is desired, it is available from the MBR loader starting
; at 0x0600:0x01be.
;===============================================================================
[ORG 0x8000]
[BITS 16]

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Fields in the kernel info structure. It is located at 0x070000 in physical
; memory.
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
DataStruct_Segment			EQU 0x7000
DataStruct_Offset			EQU 0x0000
DataStruct_Size				EQU 0xFFFF

; These are offsets within the structure itself
DataStruct_BootDrive		EQU 0x0000
DataStruct_BootPartLBA		EQU 0x0001

DataStruct_LowMem			EQU 0x0005 ; 1M to 16M, in 1KB blocks
DataStruct_HighMem			EQU 0x0009 ; Above 16M, in 64K blocks

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Various variables that hold the state of the bootloader.
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
ParamBase					EQU 0xF000

SelectedPartition			EQU ParamBase+0x0000 ; index of MBR, 0-3
BootablePartitions			EQU ParamBase+0x0001 ; Number of bootable partitions.
PartitionFlags				EQU ParamBase+0x0002 ; One byte per partition
BootPartMap					EQU	ParamBase+0x0006 ; 32 bytes per partition, string

SectorBuffer_Offset			EQU	0xF800 ; 2K buffer for sectors
SectorBuffer_Segment		EQU 0x0000

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Entry point from first stage bootloader.
;
; The first stage loader will configure the segments (DS, ES, FS and SS) to
; 0x0800 already.
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
entry:
	; Set up stack
	mov		sp, 0xF000

	; GS points to the info structure
	mov		ax, DataStruct_Segment
	mov		gs, ax

	; Initialise some state
	xor		ax, ax
	mov		word [SelectedPartition], ax

	; Enable A20 gate, then enter Unreal Mode™
	call	EnableA20
	call	EnterUnrealMode

	; Collect a bunch of information that the kernel likes
	call	CollectMemoryInfo
	call	CollectVideoInfo

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Parses the MBR for partitions.
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
ParseMBR:
	; Set up FS to point to the MBR loader
	mov		ax, 0x0600
	mov		fs, ax

	; Check four MBR entries
	mov		cx, 0x4
	mov		bx, 0x1BE

.checkPartition:
	; read the partition type: if it is nonzero, this partition is good
	mov		al, byte [fs:bx+4]
	test	al, al
	jnz		.foundPartition

.checkNext:
	; check the next partition
	add		bx, 0x10
	loop	.checkPartition

	; Now, render the main menu.
	jmp		MainMenu


; We found a partition, whose MBR entry is being pointed to by FS:BX.
.foundPartition:
	; Get the offset in the array.
	xor		edx, edx
	mov		dl, byte [BootablePartitions]

	; Clear the flags field
	mov		byte [ds:PartitionFlags+edx], 0x00

	; Is it a FAT partition?
;	cmp		al, 0x06 ; FAT16
;	je		.doFATPartition
	cmp		al, 0x0B ; FAT32 with CHS
	je		.ParseMBR_FAT
	cmp		al, 0x0C ; FAT32 with LBA
	je		.ParseMBR_FAT

	; Multiply by 32 for the string table
	shl		dx, 0x6

	; Write string to the array.
	mov		dword [ds:BootPartMap+edx], 'Part'
	mov		dword [ds:BootPartMap+edx+4], 'itio'

	; Increment the bootable partition count
	inc		byte [BootablePartitions]

	; Check the next partition.
	jmp		.checkNext

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Reads the volume label out of a FAT32 partition.
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
.ParseMBR_FAT:
	; Push array offset
	push	dx

	; Read the first sector, then display the volume name from it
	mov		eax, [fs:bx+8] ; get start LBA from MBR
	mov		[INT13_LoadPacket+8], eax

	; Attempt to read the sectors of the loader
	mov		si, INT13_LoadPacket
	mov		ah, 0x42
	mov		dl, byte [gs:DataStruct_BootDrive]
	int		0x13

	; Get array offset back
	mov dx, word [ss:esp]

	; Check for the 'PLNK' string at offset 0x60
	mov		ebx, dword [ds:SectorBuffer_Offset+0x60]
	cmp		ebx, 0x4B4E4C50
	jne		.genericFAT

	; Set the "Plonk Bootable" flag
	or		dword [ds:PartitionFlags+edx], 0x80

.genericFAT:
	; Copy partiton label from ds:esi -> es:edi
	pop		dx
	shl		dx, 0x6

	cld

	mov		di, BootPartMap
	add		di, dx

	mov		si, SectorBuffer_Offset+0x047

	; Copy 11 bytes
	mov		eax, dword [ds:si]
	mov		dword [ds:di], eax

	mov		eax, dword [ds:si+4]
	mov		dword [ds:di+4], eax

	mov		ax, word [ds:si+8]
	mov		word [ds:di+8], ax

	mov		al, byte [ds:si+10]
	mov		byte [ds:di+10], al

	; Increment the bootable partition count
	inc		byte [BootablePartitions]

	; Check the next partition.
	jmp		.checkNext

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Renders the main menu.
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
MainMenu:
	; Clear screen
	mov		ax, 0x0003
	int		0x10

	; Hide Cursor
	mov		ah, 0x01
	mov		cx, 0x2607
	int		0x10

	; Print title
	mov		bp, MsgTitle
	mov		cx, 24
	mov		dx, 0x011C
	call	PrintString

	; Draw content box holder thing
	call	DrawContentBox

	; Print advice
	mov		bp, MsgAdvice1
	mov		cx, 46
	mov		dx, 0x1511
	call	PrintString

	mov		bp, MsgAdvice2
	mov		cx, 38
	mov		dx, 0x1615
	call	PrintString

	; Are there any bootable partitions?
	mov		ah, [BootablePartitions]
	test	ah, ah
	jz		.noBootablePartitions

	; Display each of the bootable entries
	mov		bp, BootPartMap
	mov		al, [SelectedPartition]
	mov		bh, 32
	call	RenderMenu

.waitForKeypress:
	; wait for a keypress
	xor		ah, ah
	int		0x16

	; Was it an up arrow?
	cmp		ah, 0x48
	je		.upArrow

	; Was it a down arrow?
	cmp		ah, 0x50
	je		.downArrow

	; Was it the enter key?
	cmp		ah, 0x1C
	je		BootPartition

	jmp		MainMenu

; Process an up arrow press.
.upArrow:
	; Are we at the top?
	cmp		byte [SelectedPartition], 0x00
	je		MainMenu

	; If not, move up one space.
	sub		byte [SelectedPartition], 0x01
	jmp		MainMenu

; Process an down arrow press.
.downArrow:
	; Are we at the bottom?
	mov		al, byte [BootablePartitions]
	dec		al
	cmp		byte [SelectedPartition], al
	je		MainMenu

	; If not, go down one entry.
	add		byte [SelectedPartition], 0x01
	jmp		MainMenu

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Displays a message that there are no bootable partitions, then waits for the
; user to press CTRL+ALT+DEL.
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
.noBootablePartitions:
	mov		bp, MsgNoPartitions
	mov		cx, 42
	mov		dx, 0x0B13
	call	PrintString

	sti
	jmp		$

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Boots the selected partition. Determines whether it is a Plonk partition, or
; should be chainloaded.
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
BootPartition:
	; Get the index of the partition
	xor		eax, eax
	mov		al, byte [SelectedPartition]

	; Is it a Plonk partition?
	mov		bl, byte [ds:PartitionFlags+eax]
	and		bl, 0x80
	jne		BootPlonk

	; If not, chainload it.
	mov		ax, 0x0600
	mov		fs, ax

	; Add the selected partition's index to it
	mov		bx, 0x1BE
	shl		ax, 4
	add		bx, ax

	; Read LBA of the partition
	mov		eax, dword [fs:bx+8] ; get start LBA from MBR
	mov		dword [INT13_LoadPacket+8], eax

	; Write the segment and offset that chainloading is at
	mov		word [INT13_LoadPacket+4], 0x7c00
	mov		word [INT13_LoadPacket+6], 0x0000

	; Attempt to read the sectors of the loader
	mov		si, INT13_LoadPacket
	mov		ah, 0x42
	mov		dl, byte [gs:DataStruct_BootDrive]
	int		0x13

	; Reset segments
	xor		ax, ax
	mov		ds, ax
	mov		es, ax
	mov		fs, ax
	mov		gs, ax

	; Read the sector
	jmp		0x0000:0x7c00

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Attempts to boot Plonk from the partition in EAX.
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
BootPlonk:
	; Display the "loading kernel" message
	push	ax

	; Clear screen
	mov		ax, 0x0003
	int		0x10

	; Print string
	mov		bp, MsgLoadingKernel
	mov		cx, 20
	xor		dx, dx
	call	PrintString

	pop		ax

	jmp		$

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Renders a menu, where BP is a pointer to a list of strings, and AL contains
; the index to highlight. AH is the number of items, total.
;
; The total number of items is in AH. BH contains the bytes per item.
;
; This renders at (5, 5), in the content box.
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
RenderMenu:
	; Clear some regs
	xor		cx, cx
	xor		dx, dx

	; Load loop counter with total number of items
	mov		cl, ah

.renderLoop:
	; Back up registers
	push	ax
	push	cx
	push	bx

	; Regular colour
	mov		bl, 0x07

	; If ToHighlight == Current, highlight the row.
	sub		al, dl
	je		.highlight

	; Increment & save current index
	inc		dl
	push	dx

	; Render it with regular attributes
	jmp		.renderString

.highlight:
	; Inverted colours
	rol		bl, 0x4

	; Increment & save current index
	inc		dl
	push	dx

.renderString:
	; Save the attribute used to render
	mov		byte [RenderMenu_FillSpaceAttr], bl

	; Fill in the string length and coordinate
	xor		cx, cx
	mov		cl, 0x20

	; Video page 0
	xor		bh, bh

	; Set up the coordinate
	mov		dh, dl
	add		dh, 4
	and		dh, 0x1F

	mov		dl, 5
	push	dx

	; Print the string
	mov		ax, 0x1301
	int		0x10

	; Restore the X/Y start of this row
	pop		cx

	; Pop current index and bytes per item
	pop		dx
	pop		bx

	; Pad the total number of chars to 69
	mov		al, 71
	sub		al, bh
	jz		.rowFilled

	; Increment the X coordinate by the number of bytes written
	add		cl, bh

	; Render AX additional characters.
	call	RenderMenu_FillSpace

.rowFilled:
	; Increment pointer
	xor		ax, ax
	mov		al, bh
	add		bp, ax

	; Restore registers
	pop		cx
	pop		ax

	; Render any remaining rows
	loop	.renderLoop
	ret

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Writes AL number of spaces to the coordinate in CX
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
RenderMenu_FillSpace:
	; Save some state
	push	bx
	push	dx
	push	ax

	; Move coordinate from CX to DX
	mov		dx, cx
	dec		dl

	; Reposition cursor
	xor		bh, bh
	mov		ah, 0x02
	int		0x10

	; Restore number of spaces to write to CX directly
	pop		cx
	xor		ch, ch

	mov		al, 0x20
	xor		bx, bx
	mov		bl, byte [RenderMenu_FillSpaceAttr]

	mov		ah, 0x09
	int		0x10

	; We're done. Restore the registers we clobbered.
	pop		dx
	pop		bx

	ret

RenderMenu_FillSpaceAttr:
	db		0

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Draws the main content holder: it is four characters from the left, right and
; top, and eight from the bottom.
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
DrawContentBox:
	; Draw left edge at (4, 4)
	xor		bh, bh
	mov		dx, 0x0404

	mov		ah, 0x02
	int		0x10

	mov		al, 0xC9
	mov		bx, 0x000F
	mov		cx, 0x0001

	mov		ah, 0x09
	int		0x10
	; Draw top border, starting at (5, 4)
	xor		bh, bh
	mov		dx, 0x0405

	mov		ah, 0x02
	int		0x10

	mov		al, 0xCD
	mov		bx, 0x000F
	mov		cx, 0x0046

	mov		ah, 0x09
	int		0x10
	; Draw right edge at (76, 4)
	xor		bh, bh
	mov		dx, 0x044B

	mov		ah, 0x02
	int		0x10

	mov		al, 0xBB
	mov		bx, 0x000F
	mov		cx, 0x0001

	mov		ah, 0x09
	int		0x10


	; Draw left edge at (4, 19)
	xor		bh, bh
	mov		dx, 0x1304

	mov		ah, 0x02
	int		0x10

	mov		al, 0xC8
	mov		bx, 0x000F
	mov		cx, 0x0001

	mov		ah, 0x09
	int		0x10
	; Draw top border, starting at  (5, 19)
	xor		bh, bh
	mov		dx, 0x1305

	mov		ah, 0x02
	int		0x10

	mov		al, 0xCD
	mov		bx, 0x000F
	mov		cx, 0x0046

	mov		ah, 0x09
	int		0x10
	; Draw right edge at (76, 19)
	xor		bh, bh
	mov		dx, 0x134B

	mov		ah, 0x02
	int		0x10

	mov		al, 0xBC
	mov		bx, 0x000F
	mov		cx, 0x0001

	mov		ah, 0x09
	int		0x10

	; Draw left and right borders (columns 5 and 76) from row 5 to 18
	mov		cx, 14
	mov		byte [.currentY], 5

.rowLoop:
	push	cx

	; Draw the left edge
	mov		dh, byte [.currentY]
	mov		dl, 0x04
	xor		bh, bh
	mov		ah, 0x02
	int		0x10

	mov		al, 0xBA
	mov		bx, 0x000F
	mov		cx, 0x0001
	mov		ah, 0x09
	int		0x10

	; Draw the right edge
	mov		dh, byte [.currentY]
	mov		dl, 0x4B
	xor		bh, bh
	mov		ah, 0x02
	int		0x10

	mov		al, 0xBA
	mov		bx, 0x000F
	mov		cx, 0x0001
	mov		ah, 0x09
	int		0x10

	; Increment current Y
	inc		byte [.currentY]

	pop		cx
	loop	.rowLoop

	ret

.currentY:
	db		0

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Prints the string in ES:BP (length CX bytes) to the screen. Cursor position
; is in DX
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PrintString:
	; Video page 0, attribute 0: column 0
	xor		bx, bx

	; read attribute
	mov		bl, [es:bp]
	inc		bp

	mov		ax, 0x1301
	int		0x10

	ret

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Gathers memory information. This collects a map of usable memory, in addition
; to the overall size of memory.
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
CollectMemoryInfo:
	; Collect info about the total amount of memory installed
	xor		eax, eax
	xor		ebx, ebx

	mov		ax, 0xe881
	int		0x15

	; Did the BIOS output on EAX/EBX?
	test	eax, eax
	jnz		.outputEAX

	; If not, ECX and EDX should be swapped to EAX and EBX.
	xchg	eax, ecx
	xchg	ebx, edx

.outputEAX:
	mov		dword [gs:DataStruct_LowMem], eax
	mov		dword [gs:DataStruct_HighMem], ebx

	;

	ret

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Collects information about the available VBE information, such as the VBE
; version, and information about all available modes.
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
CollectVideoInfo:
	ret

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Checks if the A20 line is enabled, and if not, it tries to enable it through
; the BIOS, then the Fast A20 gate.
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
EnableA20:
	; Use the BIOS to enable the A20 gate
	mov		ax, 0x2401
	int		0x15
	jnc		.A20AlreadyOn

	; Check if the A20 gate is enabled
	in		al, 0x92
	test	al, 2
	jnz		.A20AlreadyOn

	; If not, enable it using the "Fast A20" method
	or		al, 2
	and		al, 0xfe
	out		0x92, al

.A20AlreadyOn:
	ret

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Checks if the A20 gate is enabled. AX is 0 if it is disabled, 1 otherwise.
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;CheckA20:
;	; Save the segments we are about to mess with
;	push	fs
;	push	es
;
;	; ES = 0x0000
;	xor		ax, ax
;	mov		es, ax
;
;	; DS = 0xffff
;	not		ax
;	mov		fs, ax
;
;	; Check the signatures
;	mov		di, 0x0500
;	mov		si, 0x0510
;
;	; Read 0x0000:0x0500
;	mov		al, byte [es:di]
;	push	ax
;
;	; Read 0xffff:0x0510
;	mov		al, byte [fs:si]
;	push	ax
;
;	; Write two different values to them
;	mov		byte [es:di], 0x00
;	mov		byte [fs:si], 0xFF
;
;	; Are they the same values?
;	cmp		byte [es:di], 0xFF
;
;	; Write back the old values
;	pop		ax
;	mov		byte [fs:si], al
;
;	pop		ax
;	mov		byte [es:di], al
;
;	; Clear AX: if the values are the same, return
;	xor		ax, ax
;	je		.done
;
;	; Otherwise, they're not
;	mov		al, 1
;
;.done:
;	; Pop the segments we messed with
;	pop		es
;	pop		fs
;
;	ret
;
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Enters Unreal Mode.
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
EnterUnrealMode:
	; Disable interrupts, and save real mode DS
	cli
	push	fs
	push	es
	push	ds

	; Load a 32-bit GDT
	lgdt	[.gdtinfo]

	; Enter protected mode
	mov		eax, cr0
	or		al, 0x1
	mov		cr0, eax

	; Prevent a crash on 386/486
	jmp		$+2

	; Use descriptor 1 for DS
	mov		bx, 0x08

	mov		ds, bx
	mov		es, bx
	mov		fs, bx

	; Return to real mode
	and		al,0xFE
	mov		cr0, eax

	; Get the old segment, and restore interrupts
	pop		ds
	pop		es
	pop		fs

	; Re-enable interrupts
	sti
	ret

; GDT to load
.gdtinfo:
	dw		.gdt_end - .gdt - 1
	dd		.gdt

.gdt:
	dd 0,0 
	db 0xff, 0xff, 0, 0, 0, 10010010b, 11001111b, 0
.gdt_end:

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Read packet structure for INT13 extensions.
;
; 0	1	size of packet (16 bytes)
; 1	1	always 0
; 2	2	number of sectors to transfer (max 127 on some BIOSes)
; 4	4	-> transfer buffer (16 bit segment:16 bit offset) (see note #1)
; 8	4	starting LBA
;12	4	used for upper part of 48 bit LBAs
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
INT13_LoadPacket:
	db	16, 0
	dw	4
	dw	SectorBuffer_Offset, SectorBuffer_Segment
	dd	0
	dd	0

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Message strings
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
MsgTitle: ; 24
	db		0x70, "The Plonk Bootloader 1.0"

MsgAdvice1: ; 46
	db		0x07, "Use ", 0x18, " or ", 0x19, " keys to select an operating system."
MsgAdvice2: ; 38
	db		0x07, "Press ENTER to boot, or O for options."

MsgNoPartitions: ; 42
	db		0x04, "This disk contains no bootable partitions."

MsgLoadingKernel: ; 20
	db		0x07, "Loading Plonk kernel"
MsgLoadingRamFS: ; 23
	db		0x07, "Loading initial modules"
MsgLoadingParsing: ; 18
	db		0x07, "Parsing Executables"
MsgLoadingBooting: ; 14
	db		0x07, "Booting kernel"