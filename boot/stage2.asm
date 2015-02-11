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

entry: