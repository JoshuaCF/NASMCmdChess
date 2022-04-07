%include "structs.asm"
	
	global		_main
	
	extern		_verify
	
	extern		_printBoard
	extern		_checkMove
	extern		_parseMove
	extern		_makeMove
	extern		_completeMove
	extern		_toIndex
	
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
;	db		0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41, 0x41
	db		0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
	db		0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
	db		0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
	db		0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
	db		0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
	db		0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
;	db		0x81, 0x81, 0x81, 0x81, 0x81, 0x81, 0x81, 0x81
	db		0x88, 0x82, 0x84, 0x90, 0xA0, 0x84, 0x82, 0x88
	
iend

in_fmt:	db		"%31s", 0x0
str_fmt:db		"%s", 0x0

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

err_failed_parse:
	db		"Your input is in an invalid format. Try again.", 0xD, 0xA, 0xD, 0xA, 0x0
err_no_piece:
	db		"No piece was found that could make that move.", 0xD, 0xA, 0xD, 0xA, 0x0
err_ambiguous:
	db		"More than one piece could make that move.", 0xD, 0xA, 0xD, 0xA, 0x0
err_captures_same:
	db		"You can not capture your own pieces.", 0xD, 0xA, 0xD, 0xA, 0x0
err_no_castling:
	db		"You can not castle this way.", 0xD, 0xA, 0xD, 0xA, 0x0
err_in_check:
	db		"This move leaves you in check.", 0xD, 0xA, 0xD, 0xA, 0x0
	
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
	push		board
	call		_printBoard
	add		esp, 4
	
	
	; Prompt for the user's next move
	push		move_prompt
	call		_printf
	add		esp, 4
	
	
	; Take the user's input
	push		in_bfr
	push		in_fmt
	call		_scanf
	add		esp, 8
	
	
	; Parse the move into move_bfr
	push		move_bfr
	push		in_bfr
	call		_parseMove
	add		esp, 8
	
	; Show an error message and go back to the loop start if the parse failed
	cmp		eax, 0
	je		.show_err_failed_parse
	
	
	; Ensure a piece exists that can complete the move, and check for ambiguity
	push		move_bfr
	push		board
	call		_completeMove
	add		esp, 8
	
	; If completeMove returns 1, the move is ambiguous
	cmp		eax, 1
	je		.show_err_ambiguous
	
	; If completeMove returns 2, the move has no piece
	cmp		eax, 2
	je		.show_err_no_piece
	
	
	; Ensure the move is a legal move
	push		move_bfr
	push		board
	call		_checkMove
	add		esp, 8
	
	; If checkMove returns 1, the move is not a valid castling move
	cmp		eax, 1
	je		.show_err_no_castling
	
	; If checkMove returns 2, the move attempts to capture one of its own side
	cmp		eax, 2
	je		.show_err_captures_same
	
	; If checkMove returns 3, the move leaves the player in check
	cmp		eax, 3
	je		.show_err_in_check
	
	
	; If all the components of move parsing and checking pass, then make the move on the board
	push		move_bfr
	push		board
	call		_makeMove
	add		esp, 8
	
	
	; Switch the turn to the other player
	mov		al, [board + gs_turn]
	xor		al, 1
	mov		[board + gs_turn], al
	
	; Look for stalemate/checkmate
	push		board
	call		_isCheckmate
	add		esp, 4
	cmp		eax, 1
	je		.show_checkmate
	
	push		board
	call		_isStalemate
	add		esp, 4
	cmp		eax, 1
	je		.show_stalemate
	
	; Otherwise, the game continues
	jmp		.main_loop
	
.show_checkmate:
	; If it's white's turn, push black_str. Vice versa
	mov		al, [board + gs_turn]
	cmp		al, 0
	jne		.black_wins
.white_wins:
	push		white_str
	jmp		.print_checkmate_msg
.black_wins:
	push		black_str
	
.print_checkmate_msg:	
	push		checkmate_prompt
	call		_printf
	add		esp, 8
	jmp		.epilog

.show_stalemate:
	; If it's white's turn, push white_str. Vice versa
	mov		al, [board + gs_turn]
	cmp		al, 1
	je		.black_stalemate
.white_stalemate:
	push		white_str
	jmp		.print_stalemate_msg
.black_stalemate:
	push		black_str
	
.print_stalemate_msg:
	push		stalemate_prompt
	call		_printf
	add		esp, 8
	jmp		.epilog
	
.show_err_failed_parse:
	push		err_failed_parse
	call		_printf
	add		esp, 4
	jmp		.main_loop
	
.show_err_no_piece:
	push		err_no_piece
	call		_printf
	add		esp, 4
	jmp		.main_loop
	
.show_err_ambiguous:
	push		err_ambiguous
	call		_printf
	add		esp, 4
	jmp		.main_loop
	
.show_err_captures_same:
	push		err_captures_same
	call		_printf
	add		esp, 4
	jmp		.main_loop
	
.show_err_no_castling:
	push		err_no_castling
	call		_printf
	add		esp, 4
	jmp		.main_loop
	
.show_err_in_check:
	push		err_in_check
	call		_printf
	add		esp, 4
	jmp		.main_loop
	
.epilog:
	pop		edi
	pop		esi
	pop		ebx
	pop		ebp
	
	ret