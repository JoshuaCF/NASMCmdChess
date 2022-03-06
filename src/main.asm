%include "structs.asm"
	
	global		_main
	
	global		_toIndex
	
	extern		_verify
	extern		_checkMove
	extern		_isStalemate
	extern		_isCheckmate
	
	extern		_printf
	extern		_scanf
	
	section		.data
board:
istruc game_state

at gs_turn
	db		0
at gs_bl_kingside
	db		1
at gs_wh_kingside
	db		1
at gs_bl_queenside
	db		1
at gs_wh_queenside
	db		1
at gs_passant_file
	db		0
	; This will be annoying to set up
	; a1, a2, a3... b1, b2, b3... h6, h7, h8
at gs_board
	db		0x48, 0x42, 0x44, 0x50, 0x60, 0x44, 0x42, 0x48
	db		0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41
	db		0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
	db		0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
	db		0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
	db		0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
	db		0x81, 0x81, 0x81, 0x81, 0x81, 0x81, 0x81, 0x81
	db		0x88, 0x82, 0x84, 0x90, 0xA0, 0x84, 0x82, 0x88
	
iend

in_fmt:	db		"%31s", 0x0
str_fmt:db		"%s", 0x0
char_fmt:
	db		"%c", 0x0
move_prompt:
	db		"Enter your move in algebraic notation: ", 0xD, 0xA, 0xD, 0xA, 0x0
stalemate_prompt:
	db		"%s has no legal moves, the game is a draw by stalemate.", 0xD, 0xA, 0x0
checkmate_prompt:
	db		"%s wins by checkmate.", 0xD, 0xA, 0x0
black_str:
	db		"Black", 0x0
white_str:
	db		"White", 0x0
	
	section		.bss
in_bfr:	resb		32
move_bfr:
	resb		player_move_size
	
	section		.text
_main:
.prolog:
	push		ebp
	mov		ebp, esp
	push		ebx
	push		esi
	push		edi
	
	mov		eax, 0
	; call		_verify
	
	; Main gameplay loop
.main_loop:
	; Display the board
	call		_printBoard
	
	; Prompt for the user's next move
	push		move_prompt
	call		_printf
	add		esp, 4
	
	; Take the user's input
	push		in_bfr
	push		in_fmt
	call		_scanf
	add		esp, 8
	
	; Parse and validate the move
	push		in_bfr
	push		move_bfr
	push		board
	call		_checkMove
	add		esp, 12
	
	; If the move was invalid for whatever reason, _checkMove should print out the error message. Jump back to the start and get a new move
	cmp		eax, 0
	je		.main_loop
	
	; Make the move on the board
	; Start rank should be multiplied by 8, then add the start file to get the index of the square
	mov		eax, 0
	mov		ebx, 0
	
	mov		al, [move_bfr + pm_start_file]
	push		eax
	mov		al, [move_bfr + pm_start_rank]
	push		eax
	call		_toIndex
	add		esp, 8
	
	mov		bl, [board + gs_board + eax]
	mov byte	[board + gs_board + eax], 0x00
	
	mov		al, [move_bfr + pm_destination_file]
	push		eax
	mov		al, [move_bfr + pm_destination_rank]
	push		eax
	call		_toIndex
	add		esp, 8
	
	mov		[board + gs_board + eax], bl
	
	; Switch the turn to the other player
	mov		al, [board + gs_turn]
	xor		al, 1
	mov		[board + gs_turn], al
	
	; If the next player is in stalemate, declare the game a draw and exit the loop
	push		board
	call		_isStalemate
	add		esp, 4
	
	cmp		eax, 1
	je		.stalemate
	
	; If the next player is checkmated, declare the game a win and exit the loop
	push		board
	call		_isCheckmate
	add		esp, 4
	
	cmp		eax, 1
	je		.checkmate
	
	; Otherwise, the game continues
	jmp		.main_loop
	
.stalemate:
	mov		al, [board + gs_turn]
	cmp		al, 0x00		; White's turn
	je		.stalemate_white
.stalemate_black:
	push		black_str
	jmp		.stalemate_show
.stalemate_white:
	push		white_str
.stalemate_show:
	push		stalemate_prompt
	call		_printf
	add		esp, 8
	jmp		.epilog

.checkmate:
	mov		al, [board + gs_turn]
	cmp		al, 0x00		; White's turn
	je		.checkmate_white
.checkmate_black:
	push		white_str
	jmp		.checkmate_show
.checkmate_white:
	push		black_str
.checkmate_show:
	push		checkmate_prompt
	call		_printf
	add		esp, 8
	jmp		.epilog
	
.epilog:
	pop		edi
	pop		esi
	pop		ebx
	pop		ebp
	
	ret

_printBoard:
.prolog:
	push		ebp
	mov		ebp, esp
	push		ebx
	push		esi
	
	mov		ebx, board
	add		ebx, gs_board		; ebx contains a pointer to the board
	
	add		ebx, 56			; I need to print backwards in sets of 8 to get it to display correctly
	
	; 00 000000
	; Leftmost two bits represent piece color
	; 10 = Black
	; 01 = White
	; Rightmost six bits represent piece type
	; 100000 = King
	; 010000 = Queen
	; 001000 = Rook
	; 000100 = Bishop
	; 000010 = Knight
	; 000001 = Pawn
	
	; Outer loop (loops rows)
	mov		edx, 0
.outer_loop:
	; Inner loop
	mov		ecx, 0
.inner_loop:
	mov		al, [ebx]
	and		al, 0b00111111		; Mask to get the piece, disregarding color
	
.pawn:
	cmp		al, 0b00000001		; Pawn
	jne		.knight
	mov		ah, 'P'
	jmp		.color
.knight:
	cmp		al, 0b00000010		; Knight
	jne		.bishop
	mov		ah, 'N'
	jmp		.color
.bishop:
	cmp		al, 0b00000100		; Bishop
	jne		.rook
	mov		ah, 'B'
	jmp		.color
.rook:
	cmp		al, 0b00001000		; Rook
	jne		.queen
	mov		ah, 'R'
	jmp		.color
.queen:
	cmp		al, 0b00010000		; Queen
	jne		.king
	mov		ah, 'Q'
	jmp		.color
.king:
	cmp		al, 0b00100000		; King
	jne		.empty
	mov		ah, 'K'
	jmp		.color
.empty:
	mov		ah, '-'
	jmp		.print
	
.color:
	mov		al, [ebx]
	and		al, 0b11000000		; Mask to get the color, disregarding piece
	cmp		al, 0b01000000
	je		.print
	cmp		al, 0b10000000
	jne		.print
	or		ah, 0b01100000
	
.print:
	push		edx
	push		ecx
	
	shr		eax, 8			; move ah to al
	and		eax, 0x000000FF		; clear the upper bits
	push		eax
	push		char_fmt
	call		_printf
	add		esp, 8
	
	push		' '
	push		char_fmt
	call		_printf
	add		esp, 8
	
	pop		ecx
	pop		edx
	
	inc		ebx
	inc		ecx
	cmp		ecx, 8
	jl		.inner_loop
	
	push		edx
	push		ecx
	
	push		0xA
	push		char_fmt
	call		_printf
	add		esp, 8
	
	pop		ecx
	pop		edx
	
	inc		edx
	sub		ebx, 16
	cmp		edx, 8
	jl		.outer_loop
	
.epilog:
	pop		esi
	pop		ebx
	pop		ebp
	
	ret
	
;int toIndex(char rank, char file) -> returns the numerical index of the board tile that corresponds to the given rank and file
_toIndex:
.prolog:
	push		ebp
	mov		ebp, esp
	
	; ebp + 8 = char rank
	; ebp + 12 = char file
	
	mov		eax, 0
	
	mov		al, [ebp + 8]
	sub		al, '1'
	shl		al, 3
	add		al, [ebp + 12]
	sub		al, 'a'

.epilog:
	pop		ebp
	
	ret