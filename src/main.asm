; r n b q k b n r
; p p p p p p p p
; ░ ░ ░ ░ ░ ░ ░ ░		
; ░ ░ ░ ░ ░ ░ ░ ░
; ░ ░ ░ ░ ░ ░ ░ ░ 
; ░ ░ ░ ░ ░ ░ ░ ░ 
; P P P P P P P P
; R N B Q K B N R

	global		_main
	
	extern		_verify
	extern		_checkMove
	
	extern		_printf
	
	section		.text
_main:
	mov		eax, 0
	call		_verify
	
	ret