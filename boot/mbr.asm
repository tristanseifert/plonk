;===============================================================================
; The Plonk Bootloader
;
; MBR Loader: Loads the partition bootloader of the partition marked active in
; the MBR.
;
; @note: This code relocates itself to 0x0600:0x0000.
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

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Entry point for the loader. Relocates the code to 0x0600:0x0000.
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
entry:
	; Change CS
	jmp		0x07c0:.fixSegments

.fixSegments:
	; fix segments to be the standard MBR location (0x0000:0x7c00)
	mov		ax, 0x07c0

	mov		ds, ax
	mov		es, ax

	; Set up a stack (256 bytes)
	mov		ss, ax
	mov		sp, 0x300

	; Set up segment for data struct
	mov		ax, DataStruct_Segment
	mov		gs, ax

	; Save the drive that was booted from
	mov		byte [gs:DataStruct_BootDrive], dl

	; clear the display
	mov		ax, 0x0003
	int		0x10

	; print the "Loading..." Message
	mov		bp, MsgLoading
	mov		cx, 10
	call	PrintString

	; copy this loader from ds:esi -> es:edi 0x0600:0x0000
	cld

	mov		ax, 0x0600
	mov		es, ax
	mov		di, 0x0000

	mov		si, entry

	; copy 512 bytes
	mov		cx, 512
	rep		movsb

	; jump to the relocated code
	jmp		0x0600:SearchForBootablePartition

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Searches for the active partition in the MBR, and loads it to 0x0000:0x7c00,
; then jumps into it.
;
; A bootable partition is defined as having the "Active" flag set.
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
SearchForBootablePartition:
	; Set up segments for everything else
	mov		ax, 0x07c0
	mov		ds, ax
	mov		es, ax
	mov		ss, ax

	; find the active partition
	mov		cx, 0x4
	mov		bx, 0x1BE

	; loop over all four partitions
.checkPartition:
	; read the 'flags' field and check the bootable state (bit 7)
	mov		al, byte [ds:bx]
	and		al, 0x80
	jnz		LoadPartitionBootloader

	; check the next partition
	add		bx, 0x10
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
	mov		eax, dword [ds:bx+8]
	mov		dword [gs:DataStruct_BootPartLBA], eax

	mov		dword [.loadPacket+8], eax

	push	bx

	; Read the sector
	mov		si, .loadPacket
	mov		ah, 0x42
	mov		dl, byte [gs:DataStruct_BootDrive]
	int		0x13
	jc		.diskError

	; Restore the environment: DL: drive, DS:SI MBR entry (adjust segment)
	pop		bx

	mov		si, bx
	add		si, 0x6000

	mov		dl, byte [gs:DataStruct_BootDrive]

	; Fix segments, and provide an initial SP
	xor		ax, ax

	mov		ds, ax
	mov		es, ax
	mov		fs, ax
	mov		ss, ax

	mov		sp, $8000

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
	int		0x16

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
	dw	0x7c00, 0x0000
	dd	0
	dd	0

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Prints the string in ES:BP (length CX bytes) to the screen. Video attributes
; are in BL.
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
PrintString:
	pusha

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

	popa

	ret

	; Last Y value printed to
.lastYVal:
	db		0

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Message strings
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
ENoBootablePartitions: ; 22
	db		0x47, "No Bootable Partitions"

EDiskError: ; 34
	db		0x47, "Disk Error. Press any key to retry"

MsgLoading: ; 10
	db		0x07, "Loading..."

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; MBR and signature
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	times 436-($-$$) db 255

	;; signature
	times 510-($-$$) db 0
	db 0x55
	db 0xAA