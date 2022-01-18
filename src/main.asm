	global		_main
	
	extern		_verify
	extern		_checkMove
	
	extern		_printf
	
	section		.text
_main:
	mov		eax, 0
	call		_verify
	
	ret