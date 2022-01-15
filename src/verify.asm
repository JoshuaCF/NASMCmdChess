; This file will contain a variety of functions to verify that other functions are working
	global		_verify
	
	extern		_checkMove
	
	extern		_printf
	
	section		.code
msg1:	db		"O-O", 0x0
msg2:	db		"O-O-O", 0x0
msg3:	db		"O-O-P", 0x0
msg4:	db		"OOOOP", 0x0
msg5:	db		"OOP", 0x0
msg6:	db		"OOOP", 0x0
msg7:	db		"OP", 0x0
msg8:	db		"O", 0x0
checkMove_failed:
	db		"checkMove returned %d for %s. It should have been %d", 0xD, 0xA, 0x0

	section		.bss
test_input:
	resb		10

	section		.text
_verify:
	call		_verify_checkMove
	
	ret

_verify_checkMove:
.prolog:
	push		ebx
	
	; Castling checks (unfortunately, I don't know a good way to loop this)
	push		1			; First two tests should be marked as valid
	push		msg1			; Param for checkMove
	push		0			; Param for checkMove
	call		.castling
	add		esp, 8
	
	push		msg2
	push		0
	call		.castling
	add		esp, 12
	
	push		0			; The next six should be invalid
	push		msg3
	push		0
	call		.castling
	add		esp, 8
	
	push		msg4
	push		0
	call		.castling
	add		esp, 8
	
	push		msg5
	push		0
	call		.castling
	add		esp, 8
	
	push		msg6
	push		0
	call		.castling
	add		esp, 8
	
	push		msg7
	push		0
	call		.castling
	add		esp, 8
	
	push		msg8
	push		0
	call		.castling
	add		esp, 12
	
	; Basic pawn move checks (this will need to be modified later)
	; The inputs for checkMove won't change, so I'll just push them now
	push		test_input
	push		0
	
	mov byte	[test_input+2], 0x0
	
	mov		bl, 'a'
.valid_pawns_outer:
	mov		bh, '2'
.valid_pawns_inner:
	mov		[test_input], bl
	mov		[test_input+1], bh
	call		_checkMove
	
	cmp		eax, 1
	je		.valid_pawns_skip
	
	push		1
	push		test_input
	push		eax
	push		checkMove_failed
	call		_printf
	add		esp, 16
	
.valid_pawns_skip:
	inc		bh
	cmp		bh, '7'
	jle		.valid_pawns_inner
	inc		bl
	cmp		bl, 'h'
	jle		.valid_pawns_outer
	
	; Pawn promotion checks
	mov byte	[test_input+4], 0x0
	
	mov		bl, 'a'
.valid_promotions:
	mov		[test_input], bl
	mov byte	[test_input+1], '1'
	mov byte	[test_input+2], '='
	mov byte	[test_input+3], 'N'
	call		_checkMove
	
	cmp		eax, 1
	je		.valid_promotions_skip
	
	push		1
	push		test_input
	push		eax
	push		checkMove_failed
	call		_printf
	add		esp, 16
	
.valid_promotions_skip:
	inc		bl
	cmp		bl, 'h'
	jle		.valid_promotions
	
	add		esp, 8			; Clean up those arguments from before the loops
	
.epilog:
	pop		ebx
	
	ret
	
.castling:
	; I probably should add more comments to this
	push		ebp
	mov		ebp, esp
	
	push dword	[ebp+12]
	push dword	[ebp+8]
	call		_checkMove
	add		esp, 8
	
	cmp		eax, [ebp+16]
	je		.castling_skip
	
	push dword	[ebp+16]
	push dword	[ebp+12]
	push		eax
	push		checkMove_failed
	call		_printf
	add		esp, 16
	
.castling_skip:
	pop		ebp
	ret