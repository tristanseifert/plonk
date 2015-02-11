;===============================================================================
; The Plonk Bootloader
;
; Stage 1 Loader: Loads the rest of the bootloader from the next sector in this
; partition. 
;
; This is copied to offset 0x3E in the FAT BPB.
;===============================================================================
[ORG 0x7c00]
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

; Segment of the stage 2 loader
Stage2_Segment				EQU 0x0800

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Entry in the FAT header
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Entry:
	jmp		short .init

; Align to 0x0040 for the FAT sector
	times 64-($-$$) db 0

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Actual entry point, after the BPB. This is in charge of loading the second
; stage bootloader.
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
.init:
	; Set up segments (they must be 0)
	xor		ax, ax

	mov		ds, ax
	mov		es, ax

	; reset cs to be zero as well
	jmp		0x0000:.stackInit

.stackInit:
	; Set up the stack (256 bytes)
	mov		ss, ax
	mov		sp, 0x7c00

	; Set up segment for data struct
	mov		ax, DataStruct_Segment
	mov		gs, ax

	; print the loading message
	mov		bp, MsgLoading
	mov		cx, 17
	call	PrintString

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Loads the second stage of the bootloader.
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
LoadStage2:
	; Write the LBA into the packet
	mov		eax, dword [gs:DataStruct_BootPartLBA]
	add		eax, 2
	mov		[.loadPacket+8], eax

	; Attempt to read the sectors of the loader
	mov		si, .loadPacket
	mov		ah, 0x42
	mov		dl, byte [gs:DataStruct_BootDrive]
	int		0x13
	jc		.diskError

	; Set up segment registers
	mov		ax, Stage2_Segment

	mov		ds, ax
	mov		es, ax
	mov		fs, ax
	mov		ss, ax

	; Jump to the code.
	jmp		Stage2_Segment:0x0000

; Prints an error, then waits for keyboard input and retries the read.
.diskError:
	mov		bp, EDiskError
	mov		cx, 34
	call	PrintString

	; wait for a keypress
	xor		ah, ah
	int		0x16

	; Pop the pointer and retry the load
	jmp		LoadStage2

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
.loadPacket:
	db	16, 0
	dw	4
	dw	0x0000, Stage2_Segment
	dd	0
	dd	0

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Prints the string in ES:BP (length CX bytes) to the screen.
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PrintString:
	; Video page 0, attribute 0: column 0
	xor		bx, bx
	xor		dl, dl

	; get row
	mov		dh, byte [.lastYVal]

	; read attribute
	mov		bl, [es:bp]
	inc		bp

	mov		ax, 0x1301
	int		0x10

	; increment row
	inc		byte [.lastYVal]

	ret

	; Last Y value printed to
.lastYVal:
	db		2

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Message strings
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;	times 256-($-$$) db 85
EDiskError: ; 34
	db		0x47, "Disk Error. Press any key to retry"

MsgLoading: ; 17
	db		0x07, "Loading Stage2..."

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; boot signature
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	times 510-($-$$) db 85
	db 0x55
	db 0xAA