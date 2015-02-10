;===============================================================================
; The Plonk Bootloader
;
; MBR Loader: Loads the partition bootloader of the partition marked active in
; the MBR.
;
; @note: This code relocates itself to 0x0060:0x0000.
;===============================================================================

[ORG 0x0000]
[BITS 16]

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Entry point for the loader. Relocates the code to 0x0060:0x0000.
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
entry:
	; Jump to 0x07c0:0x0000
	jmp		0x07c0:0x0000

	; fix segments to be the standard MBR location (0x0000:0x7c00)
	mov		ax, $07c0

	mov		ds, ax
	mov		ss, ax

	; Set up the stack and copy some info in the registers
	mov		sp, $300

	mov		[DriveNumber], dl

	; print the "Loading..." Message
	mov		bp, MsgLoading
	mov		cx, 10
	call	PrintString

	; copy this loader from ds:esi -> es:edi 0x0060:0x0000
	cld

	mov		ax, $0060
	mov		es, ax
	mov		di, $0000

	mov		si, entry

	; copy 512 bytes
	mov		cx, 512
	rep		movsb

	; jump to the relocated code
	jmp		0x0060:SearchForBootablePartition

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Searches for the active partition in the MBR, and loads it to 0x0000:0x7c00,
; then jumps into it.
;
; A bootable partition is defined as having the "Active" flag set.
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
SearchForBootablePartition:
	mov		ax, $07c0

	mov		ds, ax
	mov		es, ax
	mov		ss, ax

	; find the active partition
	mov		cx, $4
	mov		bx, $1BE

	; loop over all four partitions
.checkPartition:
	; read the 'flags' field and check the bootable state (bit 7)
	mov		al, [ds:bx]
	and		al, $80
	jnz		LoadPartitionBootloader

	; check the next partition
	add		bx, $10
	loop	.checkPartition

	; no bootable partitions found
	mov		bp, ENoBootablePartitions
	mov		cx, 22
	call	PrintString

	jmp		$

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; A bootable partition was found, so load its first sector and jump to it.
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
LoadPartitionBootloader:
	; Get the LBA and write it to the packet, then save ptr
	mov		eax, [ds:bx+8]
	mov		[.loadPacket+8], eax

	push	bx

	; Read the sector
	mov		si, .loadPacket
	mov		ah, $42
	mov		dl, $80
	int		$13
	jc		.diskError

	; Restore the environment: DL: drive, DS:SI MBR entry
	pop		bx

	mov		si, bx
	mov		dl, [DriveNumber]

	; jump to the code
	jmp		0x0000:0x7c00

	; Called in case of a disk error.
.diskError:

	; Print the error string
	mov		bp, EDiskError
	mov		cx, 34
	call	PrintString

	; wait for a keypress
	xor		ah, ah
	int		$16

	; Pop the pointer and retry the load
	pop		bx
	jmp		LoadPartitionBootloader

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
	dw	1
	dw	$7c00, $0000,
	dd	0
	dd	0

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Prints the string in ES:BP (length CX bytes) to the screen.
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PrintString:
	pusha

	; String is chars only, move cursor
	mov		al, $01

	; Video page 0, attribute 0: column 0
	xor		bx, bx
	xor		dl, dl

	; get row
	mov		dh, [.lastYVal]
	inc		dh
	mov		[.lastYVal], dh

	; call BIOS
	mov		ah, $13
	int		$10

	popa

	ret

	; Last Y value printed to
.lastYVal:
	db		0

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Message strings
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
ENoBootablePartitions: ; 22
	db		"No Bootable Partitions"

EDiskError: ; 34
	db		"Disk Error. Press any key to retry"

MsgLoading: ; 10
	db		"Loading..."

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; MBR and signature
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
DriveNumber: db 0

	times 446-($-$$) db 255

	;; signature
	times 510-($-$$) db 0
	db 0x55
	db 0xAA