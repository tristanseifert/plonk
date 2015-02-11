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
DataStruct_HighMem			EQU 0x0007 ; Above 16M, in 64K blocks

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Various variables that hold the state of the bootloader.
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
ParamBase					EQU 0xF000

SelectedPartition			EQU ParamBase+0x0000 ; index of MBR, 0-3
BootPartMap					EQU	ParamBase+0x0001 ; 32 bytes per partition, string

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Entry point from first stage bootloader.
;
; The first stage loader will configure the segments (DS, ES, FS and SS) to
; 0x0800 already.
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
entry:
	; Set up stack
	mov		sp, 0xF000

	; Initialise some state
	mov		byte [SelectedPartition], 0

	; Enter Unreal Mode™
	call	EnterUnrealMode

	; Collect a bunch of information that the kernel likes
	call	CollectMemoryInfo

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
	mov		bp, MsgLoading
	mov		cx, 24
	mov		dx, $011C
	call	PrintString

	; Print advice
	mov		bp, MsgAdvice1
	mov		cx, 46
	mov		dx, $1511
	call	PrintString

	mov		bp, MsgAdvice2
	mov		cx, 38
	mov		dx, $1615
	call	PrintString

	; Display each of the bootable entries
	mov		bp, MsgLoading ; BootPartMap
	mov		al, [SelectedPartition]
	mov		ah, 4
	mov		bh, 32
	call	RenderMenu

	; Draw content box holder thing
	call	DrawContentBox

	; wait for a keypress
	xor		ah, ah
	int		0x16

	; Was it an up arrow?
	cmp		ah, 0x48
	je		.upArrow

	; Was it a down arrow?
	cmp		ah, 0x50
	je		.downArrow

	jmp		MainMenu

; Process an up arrow press.
.upArrow:
	sub		byte [SelectedPartition], 0x01
	and		byte [SelectedPartition], 0x03
	jmp		MainMenu

; Process an down arrow press.
.downArrow:
	add		byte [SelectedPartition], 0x01
	and		byte [SelectedPartition], 0x03
	jmp		MainMenu

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
	mov		bl, $07

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
	mov		dx, $0404

	mov		ah, 0x02
	int		0x10

	mov		al, 0xC9
	mov		bx, 0x0007
	mov		cx, 0x0001

	mov		ah, 0x09
	int		0x10
	; Draw top border, starting at (5, 4)
	xor		bh, bh
	mov		dx, $0405

	mov		ah, 0x02
	int		0x10

	mov		al, 0xCD
	mov		bx, 0x0007
	mov		cx, 0x0046

	mov		ah, 0x09
	int		0x10
	; Draw right edge at (76, 4)
	xor		bh, bh
	mov		dx, $044B

	mov		ah, 0x02
	int		0x10

	mov		al, 0xBB
	mov		bx, 0x0007
	mov		cx, 0x0001

	mov		ah, 0x09
	int		0x10


	; Draw left edge at (4, 19)
	xor		bh, bh
	mov		dx, $1304

	mov		ah, 0x02
	int		0x10

	mov		al, 0xC8
	mov		bx, 0x0007
	mov		cx, 0x0001

	mov		ah, 0x09
	int		0x10
	; Draw top border, starting at  (5, 19)
	xor		bh, bh
	mov		dx, $1305

	mov		ah, 0x02
	int		0x10

	mov		al, 0xCD
	mov		bx, 0x0007
	mov		cx, 0x0046

	mov		ah, 0x09
	int		0x10
	; Draw right edge at (76, 19)
	xor		bh, bh
	mov		dx, $134B

	mov		ah, 0x02
	int		0x10

	mov		al, 0xBC
	mov		bx, 0x0007
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
	mov		dl, $04
	xor		bh, bh
	mov		ah, 0x02
	int		0x10

	mov		al, 0xBA
	mov		bx, 0x0007
	mov		cx, 0x0001
	mov		ah, 0x09
	int		0x10

	; Draw the right edge
	mov		dh, byte [.currentY]
	mov		dl, $4B
	xor		bh, bh
	mov		ah, 0x02
	int		0x10

	mov		al, 0xBA
	mov		bx, 0x0007
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
; Message strings
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
MsgLoading: ; 24
	db		0x70, "The Plonk Bootloader 1.0"

MsgAdvice1: ; 46
	db		0x07, "Use ", 0x18, " or ", 0x19, " keys to select an operating system."

MsgAdvice2: ; 38
	db		0x07, "Press ENTER to boot, or O for options."