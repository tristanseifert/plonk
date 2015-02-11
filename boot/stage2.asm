;===============================================================================
; The Plonk Bootloader
;
; Stage 2 loader: Provides an interface for booting operating systems. Loaded by
; stage 1.
;
; This is loaded to 0x0000:0x8000. This has the advantage of DS being zero,
; meaning we can use Unreal Mode.
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

DataStruct_LowMem:			EQU 0x0005 ; 1M to 16M, in 1KB blocks
DataStruct_HighMem:			EQU 0x0007 ; Above 16M, in 64K blocks

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Entry point from first stage bootloader.
;
; The first stage loader will configure the segments (DS, ES, FS and SS) to
; 0x0800 already.
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
entry:
	; Set up stack
	mov		sp, 0xF000

	call	EnterUnrealMode

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

	; wait for a keypress
	xor		ah, ah
	int		0x16

	jmp		MainMenu

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