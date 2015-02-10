;===============================================================================
; The Plonk Bootloader
;
; Stage 1 Loader: Loads the rest of the bootloader from the next sector in this
; partition. 
;===============================================================================

[ORG 0x7c00]

entry:

;; pad to 512 bytes
	times 510-($-$$) db 0
	db 0x55
	db 0xAA