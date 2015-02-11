;===============================================================================
; The Plonk Bootloader
;
; Stage 2 loader: Provides an interface for booting operating systems. Loaded by
; stage 1.
;
; This is loaded to 0x0800:0x0000.
;===============================================================================
[ORG 0x0000]
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
; Message strings
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
MsgLoading: ; 24
	db		0x70, "The Plonk Bootloader 1.0"