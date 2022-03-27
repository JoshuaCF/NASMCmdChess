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

err_failed_parse:
	db		"Your input is in an invalid format. Try again.", 0xD, 0xA, 0x0
err_no_piece:
	db		"No piece was found that could make that move.", 0xD, 0xA, 0x0
err_ambiguous:
	db		"More than one piece could make that move.", 0xD, 0xA, 0x0
err_captures_same:
	db		"You can not capture your own pieces.", 0xD, 0xA, 0x0
err_no_castling:
	db		"You can not castle this way.", 0xD, 0xA, 0x0
err_in_check:
	db		"This move leaves you in check.", 0xD, 0xA, 0x0
	
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
	
	; If it was a pawn move that went across two ranks, then the pawn moved twice and is a valid target for en passant
	mov		al, [move_bfr + pm_piece]
	cmp		al, 'P'
	jne		.en_passant_skip
	mov		al, [move_bfr + pm_destination_rank]
	sub		al, [move_bfr + pm_start_rank]
	cmp		al, 2
	je		.en_passant_set
	cmp		al, -2
	je		.en_passant_set
	
	; If it gets here, there is no valid en passant so clear it from the game state
	mov byte	[board + gs_passant_file], 0
	jmp		.en_passant_skip
	
.en_passant_set:
	mov		al, [move_bfr + pm_start_file]
	mov		[board + gs_passant_file], al
	
.en_passant_skip:	
	; Disable castling where applicable
	; If a start or destination file matches a corner, disable castling to that corner
	mov		al, [move_bfr + pm_start_rank]
	mov		ah, [move_bfr + pm_start_file]
	cmp		ax, 'a1'
	je		.white_queenside
	cmp		ax, 'h1'
	je		.white_kingside
	cmp		ax, 'a8'
	je		.black_queenside
	cmp		ax, 'h8'
	je		.black_kingside
	
	mov		ah, [move_bfr + pm_destination_rank]
	mov		al, [move_bfr + pm_destination_file]
	cmp		ax, 'a1'
	je		.white_queenside
	cmp		ax, 'h1'
	je		.white_kingside
	cmp		ax, 'a8'
	je		.black_queenside
	cmp		ax, 'h8'
	je		.black_kingside
	
.white_queenside:
	mov byte	[board + gs_wh_queenside], 0
	jmp		.white_castling
.white_kingside:
	mov byte	[board + gs_wh_kingside], 0
	jmp		.white_castling
.black_queenside:
	mov byte	[board + gs_bl_queenside], 0
	jmp		.white_castling
.black_kingside:
	mov byte	[board + gs_bl_kingside], 0
	jmp		.white_castling
	
	; If the king is moved, disable all castling for that player
.white_castling:
	mov		al, [board + gs_turn]
	cmp		al, 0x00
	jne		.black_castling
	mov		al, [move_bfr + pm_piece]
	cmp		al, 'K'
	jne		.black_castling
	mov byte	[board + gs_wh_queenside], 0
	mov byte	[board + gs_wh_kingside], 0
	jmp		.castling_skip
.black_castling:
	mov		al, [board + gs_turn]
	cmp		al, 0x01
	jne		.castling_skip
	mov		al, [move_bfr + pm_piece]
	cmp		al, 'K'
	jne		.castling_skip
	mov byte	[board + gs_bl_queenside], 0
	mov byte	[board + gs_bl_kingside], 0

.castling_skip:
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

