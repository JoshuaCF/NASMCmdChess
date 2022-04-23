%include "structs.asm"

	extern		_completeMove
	extern		_checkMove
	extern		_toIndex

	global		_isCheck
	global		_isStalemate
	global		_isCheckmate
	
	section		.data
	
	section		.bss
move_buffer:
	resb		player_move_size
match_value:
	resb		1
	
	section		.text
;bool isCheck(*game_state board) -> returns whether or not it is check for the current player's turn
_isCheck:
.prolog:
	push		ebp
	mov		ebp, esp
	push		ebx
	push		esi
	push		edi
	
	; ebp + 8 = *game_state board
	
.body:
	mov byte	[move_buffer + pm_piece], 0
	mov byte	[move_buffer + pm_start_file], 0
	mov byte	[move_buffer + pm_start_rank], 0
	mov byte	[move_buffer + pm_destination_file], 0
	mov byte	[move_buffer + pm_destination_rank], 0
	mov byte	[move_buffer + pm_promotion], 0
	mov byte	[move_buffer + pm_castling], 0

	mov		ebx, [ebp+8]
	
	; Construct the value that will be located (king of the current player)
	mov		eax, 0
	
	; Setting the team bits
	mov		al, [ebx+gs_turn]
	inc		al
	shl		al, 6
	
	; Setting the piece bits to king
	or		al, 0b00100000
	
	; Save the match value in esi (non-volatile register)
	mov		esi, eax
	
.find_king:
	; Locate the king of the current player
	mov		ecx, 0
	mov		edx, 0
	
	mov		cl, 'a'
	
.find_king_outer:
	mov		dl, '1'
	
.find_king_inner:
	push		ecx
	push		edx
	call		_toIndex
	add		esp, 8
	
	mov		al, [ebx+gs_board+eax]
	cmp		eax, esi
	je		.king_found
	
	inc		dl
	cmp		dl, '8'
	jle		.find_king_inner
	
	inc		cl
	cmp		cl, 'h'
	jle		.find_king_outer
	
.king_found:
	; Save the king's location as the destination of the move being checked
	mov		[move_buffer+pm_destination_file], cl
	mov		[move_buffer+pm_destination_rank], dl
	
	; Toggle the turn of the game_state
	mov		al, [ebx+gs_turn]
	xor		al, 0x01
	mov		[ebx+gs_turn], al
	
	; Construct a pmove for each piece type with the located king as the destination
	; Call _completeMove for each constructed pmove
	; If eax is ever < 2, then the current player is in check. Return 1 in eax
	mov byte	[move_buffer+pm_piece], 'Q'
	mov byte	[move_buffer+pm_start_file], 0x0
	mov byte	[move_buffer+pm_start_rank], 0x0
	push		move_buffer
	push		ebx
	call		_completeMove
	add		esp, 8
	
	cmp		eax, 2
	jl		.yes_check
	
	mov byte	[move_buffer+pm_piece], 'R'
	mov byte	[move_buffer+pm_start_file], 0x0
	mov byte	[move_buffer+pm_start_rank], 0x0
	push		move_buffer
	push		ebx
	call		_completeMove
	add		esp, 8
	
	cmp		eax, 2
	jl		.yes_check
	
	mov byte	[move_buffer+pm_piece], 'B'
	mov byte	[move_buffer+pm_start_file], 0x0
	mov byte	[move_buffer+pm_start_rank], 0x0
	push		move_buffer
	push		ebx
	call		_completeMove
	add		esp, 8
	
	cmp		eax, 2
	jl		.yes_check
	
	mov byte	[move_buffer+pm_piece], 'N'
	mov byte	[move_buffer+pm_start_file], 0x0
	mov byte	[move_buffer+pm_start_rank], 0x0
	push		move_buffer
	push		ebx
	call		_completeMove
	add		esp, 8
	
	cmp		eax, 2
	jl		.yes_check
	
	mov byte	[move_buffer+pm_piece], 'P'
	mov byte	[move_buffer+pm_start_file], 0x0
	mov byte	[move_buffer+pm_start_rank], 0x0
	push		move_buffer
	push		ebx
	call		_completeMove
	add		esp, 8
	
	cmp		eax, 2
	jl		.yes_check
	
	; If none of those are a check, then there is no check
	jmp		.no_check
	
.yes_check:
	mov		eax, 1
	jmp		.epilog
	
.no_check:
	mov		eax, 0
	
.epilog:
	; Toggle the board's turn back to the original player
	mov		cl, [ebx+gs_turn]
	xor		cl, 0x01
	mov		[ebx+gs_turn], cl
	
	pop		edi
	pop		esi
	pop		ebx
	pop		ebp
	
	ret

;bool legalMoveExists(*game_state board) - returns whether or not the current player is able to make a legal move
_legalMoveExists:
.prolog:
	push		ebp
	mov		ebp, esp
	push		edi
	push		esi
	push		ebx
	
	; ebp + 8 = *game_state board
	
	sub		esp, 16
	
	; ebp - 4 = destination file counter
	; ebp - 8 = destination rank counter
	; ebp - 12 = start file counter
	; ebp - 16 = start rank counter
	
.body:
	mov		ebx, [ebp+8]

	mov byte	[move_buffer + pm_piece], 0
	mov byte	[move_buffer + pm_start_file], 0
	mov byte	[move_buffer + pm_start_rank], 0
	mov byte	[move_buffer + pm_destination_file], 0
	mov byte	[move_buffer + pm_destination_rank], 0
	mov byte	[move_buffer + pm_promotion], 0
	mov byte	[move_buffer + pm_castling], 0
	
	mov		ecx, -1
	mov		[ebp-4], ecx
.dest_file_loop:
	mov		ecx, [ebp-4]
	inc		ecx
	mov		[ebp-4], ecx
	cmp		ecx, 8
	jge		.loops_end
	
	mov		ecx, -1
	mov		[ebp-8], ecx
.dest_rank_loop:
	mov		ecx, [ebp-8]
	inc		ecx
	mov		[ebp-8], ecx
	cmp		ecx, 8
	jge		.dest_file_loop
	
	mov		ecx, -1
	mov		[ebp-12], ecx
.start_file_loop:
	mov		ecx, [ebp-12]
	inc		ecx
	mov		[ebp-12], ecx
	cmp		ecx, 8
	jge		.dest_rank_loop
	
	mov		ecx, -1
	mov		[ebp-16], ecx
.start_rank_loop:
	mov		ecx, [ebp-16]
	inc		ecx
	mov		[ebp-16], ecx
	cmp		ecx, 8
	jge		.start_file_loop
	
	mov		al, 'a'
	add		al, [ebp-4]
	mov		[move_buffer + pm_destination_file], al
	mov		al, '1'
	add		al, [ebp-8]
	mov		[move_buffer + pm_destination_rank], al
	mov		al, 'a'
	add		al, [ebp-12]
	mov		[move_buffer + pm_start_file], al
	mov		al, '1'
	add		al, [ebp-16]
	mov		[move_buffer + pm_start_rank], al
	
.pawn:
	mov byte	[move_buffer + pm_piece], 'P'
	push		move_buffer
	push		ebx
	call		_completeMove
	add		esp, 8
	
	cmp		eax, 2
	je		.knight
	
	push		move_buffer
	push		ebx
	call		_checkMove
	add		esp, 8
	
	; The only errors we care about right here is 2 and 3
	; Both of those mean the move couldn't be made. 
	cmp		eax, 2
	je		.knight
	cmp		eax, 3
	je		.knight
	jmp		.move_exists
	
.knight:
	mov byte	[move_buffer + pm_piece], 'N'
	push		move_buffer
	push		ebx
	call		_completeMove
	add		esp, 8
	
	cmp		eax, 2
	je		.bishop
	
	push		move_buffer
	push		ebx
	call		_checkMove
	add		esp, 8
	
	; The only errors we care about right here is 2 and 3
	; Both of those mean the move couldn't be made. 
	cmp		eax, 2
	je		.bishop
	cmp		eax, 3
	je		.bishop
	jmp		.move_exists
	
.bishop:
	mov byte	[move_buffer + pm_piece], 'B'
	push		move_buffer
	push		ebx
	call		_completeMove
	add		esp, 8
	
	cmp		eax, 2
	je		.rook
	
	push		move_buffer
	push		ebx
	call		_checkMove
	add		esp, 8
	
	; The only errors we care about right here is 2 and 3
	; Both of those mean the move couldn't be made. 
	cmp		eax, 2
	je		.rook
	cmp		eax, 3
	je		.rook
	jmp		.move_exists
	
.rook:
	mov byte	[move_buffer + pm_piece], 'R'
	push		move_buffer
	push		ebx
	call		_completeMove
	add		esp, 8
	
	cmp		eax, 2
	je		.queen
	
	push		move_buffer
	push		ebx
	call		_checkMove
	add		esp, 8
	
	; The only errors we care about right here is 2 and 3
	; Both of those mean the move couldn't be made. 
	cmp		eax, 2
	je		.queen
	cmp		eax, 3
	je		.queen
	jmp		.move_exists
	
.queen:
	mov byte	[move_buffer + pm_piece], 'Q'
	push		move_buffer
	push		ebx
	call		_completeMove
	add		esp, 8
	
	cmp		eax, 2
	je		.king
	
	push		move_buffer
	push		ebx
	call		_checkMove
	add		esp, 8
	
	; The only errors we care about right here is 2 and 3
	; Both of those mean the move couldn't be made. 
	cmp		eax, 2
	je		.king
	cmp		eax, 3
	je		.king
	jmp		.move_exists
	
.king:
	mov byte	[move_buffer + pm_piece], 'K'
	push		move_buffer
	push		ebx
	call		_completeMove
	add		esp, 8
	
	cmp		eax, 2
	je		.pieces_end
	
	push		move_buffer
	push		ebx
	call		_checkMove
	add		esp, 8
	
	; The only errors we care about right here is 2 and 3
	; Both of those mean the move couldn't be made. 
	cmp		eax, 2
	je		.pieces_end
	cmp		eax, 3
	je		.pieces_end
	jmp		.move_exists
	
	
.pieces_end:
	jmp		.start_rank_loop
	
.loops_end:
	jmp		.no_move

.move_exists:
	mov		eax, 1
	jmp		.epilog
	
.no_move:
	mov		eax, 0
	
.epilog:
	add		esp, 16

	pop		ebx
	pop		esi
	pop		edi
	pop		ebp
	
	ret

;bool isStalemate(*game_state board) -> returns whether or not it's a draw by stalemate
_isStalemate:
.prolog:
	push		ebp
	mov		ebp, esp
	
	; ebp + 8 = *game_state board
	
	; Is the current player in check?
	push dword	[ebp+8]
	call		_isCheck
	add		esp, 4
	; If yes, it's not stalemate
	cmp		eax, 1
	je		.no_stalemate
	
	; Can the current player make a legal move?
	push dword	[ebp+8]
	call		_legalMoveExists
	add		esp, 4
	; If yes, it's not stalemate
	cmp		eax, 1
	je		.no_stalemate
	
	; Otherwise, it's stalemate
.stalemate:
	mov		eax, 1
	jmp		.epilog

.no_stalemate:
	mov		eax, 0
	
.epilog:
	pop		ebp
	
	ret

;bool isCheckmate(*game_state board) -> returns whether or not the current player is checkmated
_isCheckmate:
.prolog:
	push		ebp
	mov		ebp, esp
	
	; ebp + 8 = *game_state board
	
	; Is the current player in check?
	push dword	[ebp+8]
	call		_isCheck
	add		esp, 4
	; If no, it's not checkmate
	cmp		eax, 0
	je		.no_mate
	
	; Can the current player make a legal move?
	push dword	[ebp+8]
	call		_legalMoveExists
	add		esp, 4
	; If yes, it's not checkmate
	cmp		eax, 1
	je		.no_mate
	
	; Otherwise, it's checkmate
.mate:
	mov		eax, 1
	jmp		.epilog

.no_mate:
	mov		eax, 0
	
.epilog:
	pop		ebp
	
	ret