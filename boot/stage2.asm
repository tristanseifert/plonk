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
; Some configuration
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Colour_ContentBox			EQU 0x07

Colour_MenuBG				EQU 0x01

Colour_SelectedListItem		EQU 0x70
Colour_NormalListItem		EQU 0x07

Colour_HelpText				EQU 0x07
Colour_ProgressText			EQU 0x07
Colour_ErrorText			EQU 0x04

Colour_TextField			EQU 0x07
Colour_Titles				EQU 0x70

OptionsMenu_ItemLength		EQU 32
OptionsMenu_NumItems		EQU 1

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Fields in the kernel info structure. It is located at 0x070000 in physical
; memory.
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
DataStruct_Segment			EQU 0x7000
DataStruct_Offset			EQU 0x0000
DataStruct_Size				EQU 0xFFFF

; These are offsets within the structure itself
DataStruct_BootFlags		EQU 0x0000

DataStruct_BootDrive		EQU 0x0004
DataStruct_BootPartLBA		EQU 0x0005

DataStruct_LowMem			EQU 0x0009 ; 1M to 16M, in 1KB blocks
DataStruct_HighMem			EQU 0x000D ; Above 16M, in 64K blocks

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Various variables that hold the state of the bootloader.
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
StackBase					EQU 0xA000

ParamBase					EQU 0xF000

SelectedPartition			EQU ParamBase+0x0000 ; index of MBR, 0-3
BootablePartitions			EQU ParamBase+0x0001 ; Number of bootable partitions.
PartitionFlags				EQU ParamBase+0x0002 ; One byte per partition
BootPartMap					EQU	ParamBase+0x0006 ; Up to 32 bytes per partition

SelectedOption				EQU ParamBase+0x0086 ; Currently selected option
NumberOfOptions				EQU ParamBase+0x0087 ; Number of options

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
	mov		sp, StackBase

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
	; Read the MBR
	xor		eax, eax
	mov		dword [INT13_LoadPacket+8], eax

	; Attempt to read the sectors of the loader
	mov		si, INT13_LoadPacket
	mov		ah, 0x42
	mov		dl, byte [gs:DataStruct_BootDrive]
	int		0x13

	; Check four MBR entries
	mov		cx, 0x4
	mov		bx, SectorBuffer_Offset+0x1BE

.checkPartition:
	; read the partition type: if it is nonzero, this partition is good
	mov		al, byte [ds:bx+4]
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
	mov		dword [INT13_LoadPacket+8], eax

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

	; Zero-terminate the string
	mov		byte [ds:di+11], 0

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

	; Set background colour
	mov		ah, 0x0b
	mov		bx, Colour_MenuBG
	int		0x10

	; Hide Cursor
	mov		ah, 0x01
	mov		cx, 0x2607
	int		0x10

	; Print title
	mov		bp, MsgTitle
	mov		dx, 0x011C
	call	PrintString

	; Draw content box holder thing
	call	DrawContentBox

	; Print advice
	mov		bp, MsgAdvice1
	mov		dx, 0x1511
	call	PrintString

	mov		bp, MsgAdvice2
	mov		dx, 0x1615
	call	PrintString

	; Are there any bootable partitions?
	mov		ah, byte [BootablePartitions]
	test	ah, ah
	jz		.noBootablePartitions

	; Display each of the bootable entries
	mov		bp, BootPartMap
	mov		al, byte [SelectedPartition]
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
	je		.boot

	; Was it the 'O' key?
	cmp		ah, 0x18
	je		.showOptions

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

; Enters the options menu
.showOptions:
	mov		byte [SelectedOption], 0x00
	jmp		OptionsMenu

; Boots the selected partition.
.boot:
	jmp		BootPartition

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Displays a message that there are no bootable partitions, then waits for the
; user to press CTRL+ALT+DEL.
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
.noBootablePartitions:
	mov		bp, MsgNoPartitions
	mov		dx, 0x0B13
	call	PrintString

	sti
	jmp		$

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Renders the options menu.
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
OptionsMenu:
	; Read the options strings table
	mov		edi, OptionsMenuBuffer

	; Clear EBX (loop counter)
	xor		ebx, ebx

.checkNextString:
	; Is the first byte zero?
	cmp		byte [ds:di], 0
	je		.renderOptions

	; Render the checkmark
	mov		dword [ds:di], '[ ] '

	; check the bit: is it set?
	bt		dword [gs:DataStruct_BootFlags], ebx
	jnc		.notSet

	mov		byte [ds:di+1], 0x2a

.notSet:
	; How long is this string?
	mov		bp, di
	call	strlen

	; Skip over the entire length of the string
	add		di, cx

	; Process the next string.
	inc		bl
	jmp		.checkNextString

.renderOptions:
	; Clear screen
	mov		ax, 0x0003
	int		0x10

	; Set background colour
	mov		ah, 0x0b
	mov		bx, Colour_MenuBG
	int		0x10

	; Print title
	mov		bp, MsgOptionsTitle
	mov		dx, 0x011F
	call	PrintString

	; Draw content box holder thing
	call	DrawContentBox

	; Print advice
	mov		bp, MsgOptionsAdvice1
	mov		dx, 0x1516
	call	PrintString

	mov		bp, MsgOptionsAdvice2
	mov		dx, 0x1607
	call	PrintString

	; Render the menu contents
	mov		ebp, OptionsMenuBuffer
	mov		al, byte [SelectedOption]
	mov		ah, OptionsMenu_NumItems
	call	RenderMenu

	; Update cursor
	call	.updateCursorPosition

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

	; Was it the SPACE key?
	cmp		ah, 0x39
	je		.spaceKey

	; Was it the ESC key?
	cmp		ah, 0x01
	je		MainMenu

	jmp		OptionsMenu

; Process an up arrow press.
.upArrow:
	; Are we at the top?
	cmp		byte [SelectedOption], 0x00
	je		.renderOptions

	; If not, move up one space.
	sub		byte [SelectedOption], 0x01

	call	.updateCursorPosition
	jmp		.renderOptions

; Process an down arrow press.
.downArrow:
	; Are we at the bottom?
	mov		al, (OptionsMenu_NumItems - 1)
	cmp		byte [SelectedOption], al
	je		.renderOptions

	; If not, go down one entry.
	add		byte [SelectedOption], 0x01

	call	.updateCursorPosition
	jmp		.renderOptions

; Process a press of the space bar: toggle the currently selected option.
.spaceKey:
	xor		eax, eax
	mov		al, byte [SelectedOption]
	btc		dword [gs:DataStruct_BootFlags], eax

	; Since we changed the options, recalculate strings
	jmp		OptionsMenu

; Updates the cursor position
.updateCursorPosition:
	; Get the Y
	mov		dh, byte [SelectedOption]
	add		dh, 5

	; Set X and page, then update
	mov		dl, 6
	xor		bx, bx

	mov		ah, 0x02
	int		0x10

	ret

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
	mov		bl, Colour_NormalListItem

	; If ToHighlight == Current, highlight the row.
	sub		al, dl
	je		.highlight

	; Increment & save current index
	inc		dl
	push	dx

	; Render it with regular attributes
	jmp		.renderString

.highlight:
	; Use the highlight colours
	mov		bl, Colour_SelectedListItem

	; Increment & save current index
	inc		dl
	push	dx

.renderString:
	; Save the attribute used to render
	mov		byte [RenderMenu_FillSpaceAttr], bl

	; Get the string length
	call	strlen
	mov		byte [RenderMenu_Length], cl

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

	; Pad the total number of chars to 71
	mov		al, 70
	sub		al, byte [RenderMenu_Length]
	jz		.rowFilled

	; Increment the X coordinate by the number of bytes written
	add		cl, byte [RenderMenu_Length]
	inc		cl

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
RenderMenu_Length:
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
	mov		bx, Colour_ContentBox
	mov		cx, 0x0001

	mov		ah, 0x09
	int		0x10
	; Draw top border, starting at (5, 4)
	xor		bh, bh
	mov		dx, 0x0405

	mov		ah, 0x02
	int		0x10

	mov		al, 0xCD
	mov		bx, Colour_ContentBox
	mov		cx, 0x0046

	mov		ah, 0x09
	int		0x10
	; Draw right edge at (76, 4)
	xor		bh, bh
	mov		dx, 0x044B

	mov		ah, 0x02
	int		0x10

	mov		al, 0xBB
	mov		bx, Colour_ContentBox
	mov		cx, 0x0001

	mov		ah, 0x09
	int		0x10


	; Draw left edge at (4, 19)
	xor		bh, bh
	mov		dx, 0x1304

	mov		ah, 0x02
	int		0x10

	mov		al, 0xC8
	mov		bx, Colour_ContentBox
	mov		cx, 0x0001

	mov		ah, 0x09
	int		0x10
	; Draw top border, starting at  (5, 19)
	xor		bh, bh
	mov		dx, 0x1305

	mov		ah, 0x02
	int		0x10

	mov		al, 0xCD
	mov		bx, Colour_ContentBox
	mov		cx, 0x0046

	mov		ah, 0x09
	int		0x10
	; Draw right edge at (76, 19)
	xor		bh, bh
	mov		dx, 0x134B

	mov		ah, 0x02
	int		0x10

	mov		al, 0xBC
	mov		bx, Colour_ContentBox
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
	mov		bx, Colour_ContentBox
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
	mov		bx, Colour_ContentBox
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
; Prints the string in ES:BP to the screen. Cursor position is in DX.
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PrintString:
	; read attribute
	mov		bl, [es:bp]
	inc		bp

	; Find string length
	call	strlen

	; Video page 0, attribute 0: column 0
	xor		bh, bh

	mov		ax, 0x1301
	int		0x10

	ret

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Determines the length of the string in ES:BP, and returns it in CX.
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
strlen:
	xor		ecx, ecx

.loop:
	cmp		byte [es:ebp+ecx], 0
	je		.done

	inc		ecx
	jmp		.loop

.done
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

	; Did the BIOS output on EAX/EBX? (or is it worthless shit)
	test	eax, eax
	jnz		.outputEAX

	; If not, ECX and EDX should be swapped to EAX and EBX.
	xchg	eax, ecx
	xchg	ebx, edx

.outputEAX:
	mov		dword [gs:DataStruct_LowMem], eax
	mov		dword [gs:DataStruct_HighMem], ebx

	; Collect memory map

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
; Options strings table. This is modified at runtime to include the checkmark
; characters.
;
; It contains zero-terminated strings, and the table itself ends once the first
; character of a string is a zero byte.
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
OptionsMenuBuffer:
	db		"xxxxUse No eXecute bit", 0
	db		0

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Message strings
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
MsgTitle: ; 24
	db		Colour_Titles, "The Plonk Bootloader 1.0", 0
MsgAdvice1: ; 46
	db		Colour_HelpText, "Use ", 0x18, " or ", 0x19, " keys to select an operating system.", 0
MsgAdvice2: ; 38
	db		Colour_HelpText, "Press ENTER to boot, or O for options.", 0

MsgOptionsTitle: ; 18
	db		Colour_Titles, "Plonk Boot Options", 0
MsgOptionsAdvice1: ; 36
	db		Colour_HelpText, "Use ", 0x18, " or ", 0x19, " keys to select an option.", 0
MsgOptionsAdvice2: ; 66
	db		Colour_HelpText, "Press SPACE to toggle an option, and ESC to exit to the main menu.", 0

MsgNoPartitions: ; 42
	db		Colour_ErrorText, "This disk contains no bootable partitions.", 0

MsgLoadingKernel: ; 20
	db		Colour_ProgressText, "Loading Plonk kernel", 0
MsgLoadingRamFS: ; 23
	db		Colour_ProgressText, "Loading initial modules", 0
MsgLoadingParsing: ; 18
	db		Colour_ProgressText, "Parsing executables", 0
MsgLoadingBooting: ; 14
	db		Colour_ProgressText, "Booting kernel", 0