%include "structs.asm"

	global		_checkMove
	global		_parseMove
	global		_completeMove
	global		_makeMove
	global		_printBoard
	global		_toIndex
	
	extern		_printf
	
	extern		_isCheck

	section		.text
; int checkMove(game_state* board, player_move* pmove)
; 0 = OK
; 1 = error - invalid castling
; 2 = error - self capturing
; 3 = error - in check
_checkMove:
.prolog:
	push		ebp
	mov		ebp, esp
	; [ebp + 8] = arg 1
	; [ebp + 12] = arg 2
	push		ebx
	push		esi
	push		edi
	
	mov		edi, [ebp+12]		; pmove ptr
	; TODO: If the move is castling, the checks are a bit different
.validate_castling:

.look_for_self_captures:
	; If the destination square contains a piece that belongs to the current player, the move fails
	mov		eax, 0
	mov		al, [edi + pm_destination_file]
	push		eax
	mov		al, [edi + pm_destination_rank]
	push		eax
	call		_toIndex
	add		esp, 8
	
	mov		ebx, [ebp+8]		; board ptr
	
	; al contains the two high value bits, which represent team
	; 0b01000000 = white piece
	; 0b10000000 = black piece
	mov		al, [ebx + eax + gs_board]
	cmp		al, 0x00
	je		.look_for_check
	and		al, 0b11000000
	
	; Doing some weirdness here... this will cut down on the amount of comparisons I have to do though.
	; Load into bl the value that represents whose turn it is
	; 0b00000000 = white's turn
	; 0b00000001 = black's turn
	mov		bl, [ebx + gs_turn]
	
	; Increment this
	; 0b00000001 = white's turn
	; 0b00000010 = black's turn
	inc		bl
	
	; Shift left 6 bits
	; 0b01000000 = white's turn
	; 0b10000000 = black's turn
	shl		bl, 6
	
	; Compare with the team bits of the piece
	; If it matches, then the player is moving onto their own piece
	cmp		al, bl
	jne		.look_for_check
	jmp		.invalid_self_capture
	
.look_for_check:

.invalid_castling:	
.invalid_self_capture:
.invalid_in_check:
.valid:
	
.epilog:
	pop		edi
	pop		esi
	pop		ebx
	pop		ebp
	ret

	section		.bss
in_len:
	resd		1
	
	section		.text
; bool parseMove(char* input, player_move* pmove) -> returns whether or not parsing failed
_parseMove:
.prolog:
	push		ebp
	mov		ebp, esp
	push		ebx
	push		esi
	push		edi
	
	; [ebp+8] = input
	; [ebp+12] = pmove

	mov		edi, [ebp+12]		; Pointer to pmove

	mov byte	[edi + pm_piece], 0
	mov byte	[edi + pm_start_file], 0
	mov byte	[edi + pm_start_rank], 0
	mov byte	[edi + pm_destination_file], 0
	mov byte	[edi + pm_destination_rank], 0
	mov byte	[edi + pm_promotion], 0
	mov byte	[edi + pm_castling], 0
	
	; Algebraic notation:
	; [piece][file][rank]["x"]destination[=piece]
	; Special cases:
	; O-O
	; O-O-O
	
; COUNTING MESSAGE LENGTH
	; Count message length and store it
	mov		ecx, 0			; Counter = 0
	mov		ebx, [ebp+8]		; Pointer to the input string
.counting:
	mov		dl, [ebx+ecx]		; Cur character
	cmp		dl, 0			; Is null?
	je		.counting_end		; Exit loop if yes
	inc		ecx			; Increase count if no
	jmp		.counting
.counting_end:
	mov		[in_len], ecx		; Store input length
	
	cmp		ecx, 1			; If it's one or fewer characters, it's invalid
	jle		.invalid
	
; PARSING THE INPUT
	; Go through each character, determining its purpose and if its valid
	mov		ecx, 0			; Start on character 0
	
	; Check for special cases first
	mov		dl, [ebx+ecx]		; Current character (should always be the first character at this point)
	cmp		dl, 'O'			; If the input starts with this, jump to checking for special cases
	je		.special

.parsePiece:
; DETERMINING THE PIECE
	; The first character must be an uppercase letter K, Q, R, N, B, or lowercase letter a-h (castling was already checked for)
	cmp		dl, 'K'
	je		.not_pawn
	cmp		dl, 'Q'
	je		.not_pawn
	cmp		dl, 'R'
	je		.not_pawn
	cmp		dl, 'N'
	je		.not_pawn
	cmp		dl, 'B'
	je		.not_pawn
	
	; If it isn't one of the uppercase letters, it can NOT be outside the range of a-h
	cmp		dl, 'a'
	jl		.invalid
	cmp		dl, 'h'
	jg		.invalid
	jmp		.pawn
	
.not_pawn:
	; If we get here, it's not a pawn and the current letter is the piece
	mov byte	[edi + pm_piece], dl
	inc		ecx
	
	jmp		.parseDisambiguation
	
.pawn:
	; If we get here, it's definitely a pawn move, starting on the file of this character
	; We can go ahead and do disambiguation stuff since pawns are a little weird
	mov byte	[edi + pm_piece], 'P'
	mov byte	[edi + pm_start_file], dl
	
	; Pawn moves are always an even length (a4, axb4, a8=Q, axb8=Q)
	mov		edx, 0
	mov		eax, [in_len]
	mov		esi, 2
	idiv		esi
	; EDX contains the remainder, EAX contains the quotient
	cmp		edx, 0
	jne		.invalid
	
	; If the second character is an "x", go ahead and skip it before jumping to destination parsing
	mov		dl, [ebx+ecx+1]
	cmp		dl, 'x'
	jne		.parseDestination
	
	add		ecx, 2
	
	jmp		.parseDestination

.parseDisambiguation:
; DETERMINE DISAMBIGUATION CHARACTERS (if any)
	; Load the next character
	mov		dl, [ebx+ecx]

	; At this point, there's three possibilities:
	; The next two characters are the destination squares
	; There are one or two characters of disambiguation
	; The next character is an "x", specifying a capture
	
	; Pawns were already handled as a semi-special case, so there won't be any promotion characters
	
	; If the next character is an "x", there are no disambiguation characters
	cmp		dl, 'x'
	jne		.disamSkip
	inc		ecx			; If it's an x, skip it and jump to determining destination
	jmp		.parseDestination
	
.disamSkip:
	; The current possible formats:
	; Bd4
	; Bc3d4
	; Bcd4
	; B3d4
	; Bc3xd4
	; Bcxd4
	; B3xd4
	
	; If it's only a 3 character input (Bd4), then jump to destination parsing
	mov		eax, [in_len]
	cmp		eax, 3
	je		.parseDestination
	
	; The current possible formats:
	; Bc3d4
	; Bcd4
	; B3d4
	; Bc3xd4
	; Bcxd4
	; B3xd4
.disamFile:
	; If it's more than 3 characters, the current character is disambiguation. See if it's a file, then rank
	cmp		dl, 'a'
	jl		.disamRank
	cmp		dl, 'h'
	jg		.disamRank
	
	; The current character is a file disambiguation character
	mov		[edi + pm_start_file], dl
	inc		ecx
	mov		dl, [ebx+ecx]
	
	; If the next character is an 'x', we're done
	cmp		dl, 'x'
	jne		.disamRank
	inc		ecx
	jmp		.parseDestination
	
	; The current possible formats:
	; Bc3d4
	; Bcd4
	; B3d4
	; Bc3xd4
	; B3xd4
.disamRank:
	; If we get here, the next character must be a number 1-8 in order for it to be a disambiguation character
	; If it fails to be a number 1-8, jump to destination parsing
	cmp		dl, '1'
	jl		.parseDestination
	cmp		dl, '8'
	jg		.parseDestination
	
	; The current character is a rank disambiguation character
	mov		[edi + pm_start_rank], dl
	inc		ecx
	mov		dl, [ebx+ecx]
	
	; The current possible formats:
	; Bc3d4
	; B3d4
	; Bc3xd4
	; B3xd4
	
	; parseDestination does not expect to be put on an 'x', so if this character is an x, skip it before going to parse destination
	cmp		dl, 'x'
	jne		.parseDestination
	inc		ecx
	jmp		.parseDestination
	
.parseDestination:
; DETERMINE DESTINATION
	; Load the next character
	mov		dl, [ebx+ecx]
	
	; At this point, there should only be a destination and possibly a promotion if it's a pawn remaining
	; Determining destination is easy at the moment -- it should be the next two characters, but we need to ensure they're a-h and 1-8
	; Checking a-h for file
	cmp		dl, 'a'
	jl		.invalid
	cmp		dl, 'h'
	jg		.invalid
	
	mov		[edi + pm_destination_file], dl
	
	; Checking 1-8 for rank
	inc		ecx
	
	mov		dl, [ebx+ecx]
	
	cmp		dl, '1'
	jl		.invalid
	cmp		dl, '8'
	jg		.invalid
	
	mov		[edi + pm_destination_rank], dl
	
	inc		ecx
	
	; If the destination rank is one of the back ranks and the current piece is a pawn, then jump to promotion determination. There MUST be a promotion listed.
	cmp		dl, '8'
	je		.is_back_rank
	cmp		dl, '1'
	je		.is_back_rank
	
	; Otherwise, if there are still characters remaining, then the string is invalid
	cmp		ecx, [in_len]
	jl		.invalid
	jmp		.valid
	
.is_back_rank:
	mov		dl, [edi + pm_piece]
	cmp		dl, 'P'
	je		.parsePromotion
	jmp		.valid			; If it's not a pawn and it's a backrank move, then don't worry about checking promotions

.parsePromotion:
; DETERMINING PROMOTIONS
	
	; The next character must be an equals sign "="
	mov		dl, [ebx+ecx]
	cmp		dl, '='
	jne		.invalid
	
	; The next character must be Q, R, B, or N
	inc		ecx
	mov		dl, [ebx+ecx]
	
	; This will be kind of ugly. I don't know a better way to do this in NASM
	; This is basically if else if else if else if else
	cmp		dl, 'Q'
	jne		.promotionSkip1
	
	mov		[edi + pm_promotion], dl
	jmp		.valid
.promotionSkip1:
	cmp		dl, 'R'
	jne		.promotionSkip2
	
	mov		[edi + pm_promotion], dl
	jmp		.valid
.promotionSkip2:
	cmp		dl, 'B'
	jne		.promotionSkip3
	
	mov		[edi + pm_promotion], dl
	jmp		.valid
.promotionSkip3:
	cmp		dl, 'N'
	jne		.invalid		; If we're checking for the last valid character and it doesn't match, then it's invalid
	
	mov		[edi + pm_promotion],dl
	jmp		.valid
	
; DETERMINING CASTLING
	; If the input is some form of castling, figure out which one it is
.special:
	; If the length is not 5 or 3 characters, it's invalid. Otherwise, check for the corresponding castling
	mov		edx, [in_len]
	cmp		edx, 5			; Should be queenside
	je		.queenside
	
	cmp		edx, 3			; Should be kingside
	je		.kingside
	
	jmp		.invalid		; If the length doesn't match kingside or queenside length, but it starts with 'O', the input is invalid
.queenside:
	mov		edx, [ebx+1]
	cmp		edx, '-O-O'		; Convenient way to check four characters
	mov byte	[edi + pm_castling], 2		; castling=2 is queenside castling (it's okay if it jumps to invalid after this -- this will get ignored)
	je		.valid
	jmp		.invalid
.kingside:
	mov		dx, [ebx+1]
	cmp		dx, '-O'		; Same as above but with two characters
	mov byte	[edi + pm_castling], 1		; castling=1 is kingside castling
	je		.valid
	jmp		.invalid
	
	; An invalid input will jump here
.invalid:
	mov		eax, 0
	jmp		.epilog
	
	; A valid input will jump here
.valid:
	mov		eax, 1
	
.epilog:
	pop		edi
	pop		esi
	pop		ebx
	pop		ebp
	
	ret
	
	section		.data
knight_offsets:					; Easier to iterate over these than generate them imo
	db		1,2
	db		2,1
	db		2,-1
	db		1,-2
	db		-1,-2
	db		-2,-1
	db		-2,1
	db		-1,2
king_offsets:
	db		0,1
	db		1,1
	db		1,0
	db		1,-1
	db		0,-1
	db		-1,-1
	db		-1,0
	db		-1,1
	
	section		.bss
potential_pieces_arr:
	resw		8
potential_pieces:
	resb		1
matched_index:
	resb		1
match_value:
	resb		1
	
	section		.text
	
;int completeMove(game_state* board, player_move* pmove) -> a integer representing whether or not one piece was found that can make the move
; 0 = OK
; 1 = error - ambiguous move
; 2 = error - no move
_completeMove:
.prolog:
	push		ebp
	mov		ebp, esp
	push		ebx
	push		esi
	push		edi
	
	; [ebp+8] = game_state* board
	; [ebp+12] = player_move* pmove
	
	mov		edi, [ebp+12]		; pointer to pmove
	; edi won't be modified for the entirety of this subroutine
	
	; Set the team bits of match_value
	mov		ebx, [ebp+8]
	mov		al, [ebx+gs_turn]
	cmp		al, 0			; If it's white turn
	je		.white
	cmp		al, 1			; If it's black's turn
	je		.black
.white:
	mov		ah, 0b01000000
	jmp		.determine_piece
.black:
	mov		ah, 0b10000000
	
.determine_piece:
	; Check what piece is being moved
	; Find where pieces exist and add them to a list of pieces that will be checked for the correct piece later
	; IF PAWN
	; ugh.
	; IF BISHOP, ROOK, OR QUEEN
	; Iterate outwards from the destination square until a piece is hit or it goes off the board
	; IF KNIGHT
	; Check the 8 locations a knight could jump from, ensuring each location is on the board
	; IF KING
	; Check the 8 tiles adjacent to the destination square, ensuring each location is on the board
	
	mov byte	[potential_pieces], 0
	
	mov		al, [edi + pm_piece]
	
	cmp		al, 'P'
	je		.pawn
	
	cmp		al, 'N'
	je		.knight
	
	cmp		al, 'K'
	je		.king
	
	cmp		al, 'B'
	je		.bishop
	
	cmp		al, 'R'
	je		.rook
	
	cmp		al, 'Q'
	je		.queen
	
.pawn:						; TODO
	jmp		.locate_matches
	
.king:
	; Complete the match value
	or		ah, 0b00100000
	mov		[match_value], ah
	
	; Set esi to the array that will be used for the 8 offsets
	mov		esi, king_offsets
	
	; Jump to offset checks
	jmp		.offset_compute
	
.knight:
	; Complete the match value
	or		ah, 0b00000010
	mov		[match_value], ah
	
	; Set esi to the array that will be used for the 8 offsets
	mov		esi, knight_offsets
	
	; Jump to offset checks
	jmp		.offset_compute
	
.bishop:
	; Complete the match value
	or		ah, 0b00000100
	mov		[match_value], ah
	
	; Jump to diagonal checks
	jmp		.diagonal_compute
	
.rook:
	; Complete the match value
	or		ah, 0b00001000
	mov		[match_value], ah
	
	; Jump to orthogonal checks
	jmp		.orthogonal_compute
	
.queen:
	; Complete the match value
	or		ah, 0b00010000
	mov		[match_value], ah
	
	; Jump to diagonal checks (diagonal checks will check for queen and proceed to orthogonal checks if it is)
	jmp		.diagonal_compute

.offset_compute:
	; Loop through each possible offset of the destination tile, computing the index
	; If the offset results in a position off the board, skip the rest of the iteration
	mov		ebx, [ebp+8]
	add		ebx, gs_board
	
	mov		eax, 0
	mov		ecx, 0
.offset_loop:
	; Compute the potential starting file
	mov		al, [edi + pm_destination_file]
	add		al, [esi + ecx]
	
	; Ensure this is still on the board
	cmp		al, 'a'
	jl		.offset_continue
	cmp		al, 'h'
	jg		.offset_continue
	
	; Store it in the potential pieces array
	; NOTE: the potential pieces array is being used for this as just a temporary storage location
	; if the location actually ends up containing a piece to get checked later, then conveniently the data is already where it needs to be saved
	; we just have to increment the amount of items in the array so it won't get destroyed on the next iteration
	mov		edx, 0
	mov		dl, [potential_pieces]
	mov		[potential_pieces_arr + edx*2], al
	
	; Compute the potential starting rank
	mov		al, [edi + pm_destination_rank]
	add		al, [esi + ecx + 1]
	
	; Ensure this is still on the board
	cmp		al, '1'
	jl		.offset_continue
	cmp		al, '8'
	jg		.offset_continue
	
	; Store it in the potential pieces array
	mov		[potential_pieces_arr + edx*2 + 1], al
	
	; Save the loop variable
	push		ecx
	
	; Compute the index of the potential start position
	mov		al, [potential_pieces_arr + edx*2]
	push		eax
	mov		al, [potential_pieces_arr + edx*2 + 1]
	push		eax
	call		_toIndex
	add		esp, 8
	
	; Recover the loop variable
	pop		ecx
	
	; Check if the computed board position is empty
	mov		dl, [ebx + eax]
	cmp		dl, 0x00
	je		.offset_continue
	
	; If it isn't empty, increment the potential_pieces amount so that the computed start values are saved
	mov		dl, [potential_pieces]
	inc		dl
	mov		[potential_pieces], dl
	
.offset_continue:
	add		ecx, 2
	cmp		ecx, 16
	jl		.offset_loop
	
	jmp		.locate_matches
	
.diagonal_compute:
	; esi = board = gs_board
	mov		esi, [ebp + 8]
	add		esi, gs_board
	
	; Four loops for each diagonal direction
	; Lots of code copying here, but I don't really care.
	mov		bh, [edi + pm_destination_file]
	mov		bl, [edi + pm_destination_rank]
	
	; Towards top right
.diagonal_loop1:
	inc		bh
	cmp		bh, 'a'
	jl		.diagonal_loop1_exit
	cmp		bh, 'h'
	jg		.diagonal_loop1_exit
	
	inc		bl
	cmp		bl, '1'
	jl		.diagonal_loop1_exit
	cmp		bl, '8'
	jg		.diagonal_loop1_exit
	
	mov		eax, 0
	mov		al, bh
	push		eax
	mov		al, bl
	push		eax
	call		_toIndex
	add		esp, 8
	
	; Check if the position is empty. Repeat if so
	mov		al, [esi + eax]
	cmp		al, 0x00
	je		.diagonal_loop1
	
	; Otherwise, add the position to potential_pieces_arr
	mov		eax, 0
	mov		al, [potential_pieces]
	
	mov		[potential_pieces_arr + eax*2], bh
	mov		[potential_pieces_arr + eax*2 + 1], bl
	
	inc		al
	mov		[potential_pieces], al
.diagonal_loop1_exit:

	mov		bh, [edi + pm_destination_file]
	mov		bl, [edi + pm_destination_rank]
	
	; Towards top left
.diagonal_loop2:
	dec		bh
	cmp		bh, 'a'
	jl		.diagonal_loop2_exit
	cmp		bh, 'h'
	jg		.diagonal_loop2_exit
	
	inc		bl
	cmp		bl, '1'
	jl		.diagonal_loop2_exit
	cmp		bl, '8'
	jg		.diagonal_loop2_exit
	
	mov		eax, 0
	mov		al, bh
	push		eax
	mov		al, bl
	push		eax
	call		_toIndex
	add		esp, 8
	
	; Check if the position is empty. Repeat if so
	mov		al, [esi + eax]
	cmp		al, 0x00
	je		.diagonal_loop2
	
	; Otherwise, add the position to potential_pieces_arr
	mov		eax, 0
	mov		al, [potential_pieces]
	
	mov		[potential_pieces_arr + eax*2], bh
	mov		[potential_pieces_arr + eax*2 + 1], bl
	
	inc		al
	mov		[potential_pieces], al
.diagonal_loop2_exit:

	mov		bh, [edi + pm_destination_file]
	mov		bl, [edi + pm_destination_rank]
	
	; Towards bottom right
.diagonal_loop3:
	inc		bh
	cmp		bh, 'a'
	jl		.diagonal_loop3_exit
	cmp		bh, 'h'
	jg		.diagonal_loop3_exit
	
	dec		bl
	cmp		bl, '1'
	jl		.diagonal_loop3_exit
	cmp		bl, '8'
	jg		.diagonal_loop3_exit
	
	mov		eax, 0
	mov		al, bh
	push		eax
	mov		al, bl
	push		eax
	call		_toIndex
	add		esp, 8
	
	; Check if the position is empty. Repeat if so
	mov		al, [esi + eax]
	cmp		al, 0x00
	je		.diagonal_loop3
	
	; Otherwise, add the position to potential_pieces_arr
	mov		eax, 0
	mov		al, [potential_pieces]
	
	mov		[potential_pieces_arr + eax*2], bh
	mov		[potential_pieces_arr + eax*2 + 1], bl
	
	inc		al
	mov		[potential_pieces], al
.diagonal_loop3_exit:

	mov		bh, [edi + pm_destination_file]
	mov		bl, [edi + pm_destination_rank]
	
	; Towards bottom left
.diagonal_loop4:
	dec		bh
	cmp		bh, 'a'
	jl		.diagonal_loop4_exit
	cmp		bh, 'h'
	jg		.diagonal_loop4_exit
	
	dec		bl
	cmp		bl, '1'
	jl		.diagonal_loop4_exit
	cmp		bl, '8'
	jg		.diagonal_loop4_exit
	
	mov		eax, 0
	mov		al, bh
	push		eax
	mov		al, bl
	push		eax
	call		_toIndex
	add		esp, 8
	
	; Check if the position is empty. Repeat if so
	mov		al, [esi + eax]
	cmp		al, 0x00
	je		.diagonal_loop4
	
	; Otherwise, add the position to potential_pieces_arr
	mov		eax, 0
	mov		al, [potential_pieces]
	
	mov		[potential_pieces_arr + eax*2], bh
	mov		[potential_pieces_arr + eax*2 + 1], bl
	
	inc		al
	mov		[potential_pieces], al
.diagonal_loop4_exit:

	; If the piece is a queen, also do an orthogonal check
	mov		al, [edi + pm_piece]
	cmp		al, 'Q'
	je		.orthogonal_compute
	
	jmp		.locate_matches

.orthogonal_compute:
	; esi = board = gs_board
	mov		esi, [ebp + 8]
	add		esi, gs_board
	
	; Four loops for each diagonal direction
	; Lots of code copying here, but I don't really care.
	mov		bh, [edi + pm_destination_file]
	mov		bl, [edi + pm_destination_rank]
	
	; Towards top
.orthogonal_loop1:
	inc		bl
	cmp		bl, '1'
	jl		.orthogonal_loop1_exit
	cmp		bl, '8'
	jg		.orthogonal_loop1_exit
	
	mov		eax, 0
	mov		al, bh
	push		eax
	mov		al, bl
	push		eax
	call		_toIndex
	add		esp, 8
	
	; Check if the position is empty. Repeat if so
	mov		al, [esi + eax]
	cmp		al, 0x00
	je		.orthogonal_loop1
	
	; Otherwise, add the position to potential_pieces_arr
	mov		eax, 0
	mov		al, [potential_pieces]
	
	mov		[potential_pieces_arr + eax*2], bh
	mov		[potential_pieces_arr + eax*2 + 1], bl
	
	inc		al
	mov		[potential_pieces], al
.orthogonal_loop1_exit:

	mov		bh, [edi + pm_destination_file]
	mov		bl, [edi + pm_destination_rank]
	
	; Towards bottom
.orthogonal_loop2:
	dec		bl
	cmp		bl, '1'
	jl		.orthogonal_loop2_exit
	cmp		bl, '8'
	jg		.orthogonal_loop2_exit
	
	mov		eax, 0
	mov		al, bh
	push		eax
	mov		al, bl
	push		eax
	call		_toIndex
	add		esp, 8
	
	; Check if the position is empty. Repeat if so
	mov		al, [esi + eax]
	cmp		al, 0x00
	je		.orthogonal_loop2
	
	; Otherwise, add the position to potential_pieces_arr
	mov		eax, 0
	mov		al, [potential_pieces]
	
	mov		[potential_pieces_arr + eax*2], bh
	mov		[potential_pieces_arr + eax*2 + 1], bl
	
	inc		al
	mov		[potential_pieces], al
.orthogonal_loop2_exit:

	mov		bh, [edi + pm_destination_file]
	mov		bl, [edi + pm_destination_rank]
	
	; Towards right
.orthogonal_loop3:
	inc		bh
	cmp		bh, 'a'
	jl		.orthogonal_loop3_exit
	cmp		bh, 'h'
	jg		.orthogonal_loop3_exit
	
	mov		eax, 0
	mov		al, bh
	push		eax
	mov		al, bl
	push		eax
	call		_toIndex
	add		esp, 8
	
	; Check if the position is empty. Repeat if so
	mov		al, [esi + eax]
	cmp		al, 0x00
	je		.orthogonal_loop3
	
	; Otherwise, add the position to potential_pieces_arr
	mov		eax, 0
	mov		al, [potential_pieces]
	
	mov		[potential_pieces_arr + eax*2], bh
	mov		[potential_pieces_arr + eax*2 + 1], bl
	
	inc		al
	mov		[potential_pieces], al
.orthogonal_loop3_exit:

	mov		bh, [edi + pm_destination_file]
	mov		bl, [edi + pm_destination_rank]
	
	; Towards left
.orthogonal_loop4:
	dec		bh
	cmp		bh, 'a'
	jl		.orthogonal_loop4_exit
	cmp		bh, 'h'
	jg		.orthogonal_loop4_exit
	
	mov		eax, 0
	mov		al, bh
	push		eax
	mov		al, bl
	push		eax
	call		_toIndex
	add		esp, 8
	
	; Check if the position is empty. Repeat if so
	mov		al, [esi + eax]
	cmp		al, 0x00
	je		.orthogonal_loop4
	
	; Otherwise, add the position to potential_pieces_arr
	mov		eax, 0
	mov		al, [potential_pieces]
	
	mov		[potential_pieces_arr + eax*2], bh
	mov		[potential_pieces_arr + eax*2 + 1], bl
	
	inc		al
	mov		[potential_pieces], al
.orthogonal_loop4_exit:
	jmp		.locate_matches
	
.locate_matches:
	mov byte	[matched_index], -1
	
	; If the number of potential pieces is zero, jump to err_no_piece
	cmp byte	[potential_pieces], 0
	je		.err_no_piece
	
	; Iterate through the list of potential pieces, looking for matches
	mov		ecx, 0
.match_loop:
	; If there is a start_file, ensure it matches
	mov		al, [edi + pm_start_file]
	cmp		al, 0
	je		.start_file_skip
	
	cmp		al, [potential_pieces_arr + ecx*2]
	jne		.match_loop_continue
	
.start_file_skip:
	; If there is a start_rank, ensure it matches
	mov		al, [edi + pm_start_rank]
	cmp byte	al, 0
	je		.start_rank_skip
	
	cmp byte	al, [potential_pieces_arr + ecx*2 + 1]
	jne		.match_loop_continue
	
.start_rank_skip:
	; Save the counter variable
	push		ecx
	
	; Compute the index of the tile
	mov		eax, 0
	mov		al, [potential_pieces_arr + ecx*2]
	push		eax
	mov		al, [potential_pieces_arr + ecx*2 + 1]
	push		eax
	call		_toIndex
	add		esp, 8
	
	; Restore the counter variable
	pop		ecx
	
	; If a piece is found that matches the piece value and matched_index is not -1, store its index in matched_index
	mov		ebx, [ebp+8]
	add		ebx, gs_board		; Board pointer
	
	mov		dl, [match_value]
	cmp		dl, [ebx+eax]
	jne		.match_loop_continue
	
	cmp byte	[matched_index], -1
	; If a match is found and there was already a match, jump to err_ambiguous
	jne		.err_ambiguous
	
	mov		[matched_index], cl
	
.match_loop_continue:
	inc		ecx
	cmp		cl, [potential_pieces]
	jl		.match_loop
	
	; If no piece was found, jump to err_no_piece
	cmp byte	[matched_index], -1
	je		.err_no_piece
	
	; Otherwise, fill in the move details
	mov		eax, 0
	mov		ebx, 0
	mov		bl, [matched_index]
	
	mov		al, [potential_pieces_arr + ebx*2]
	mov		[edi + pm_start_file], al
	mov		al, [potential_pieces_arr + ebx*2 + 1]
	mov		[edi + pm_start_rank], al
	
	jmp		.valid

.valid:
	mov		eax, 0
	jmp		.epilog

.err_ambiguous:
	mov		eax, 1
	jmp		.epilog
	
.err_no_piece:
	mov		eax, 2
	
.epilog:
	pop		edi
	pop		esi
	pop		ebx
	pop		ebp
	ret
	
	section		.data
char_fmt:
	db		"%c", 0x0
	
;void printBoard(game_state* board)
; Prints out the board passed
_printBoard:
.prolog:
	push		ebp
	mov		ebp, esp
	push		ebx
	push		esi
	
	; [ebp+8] = board
	
	mov		ebx, [ebp+8]
	add		ebx, gs_board		; ebx contains a pointer to the board tiles
	
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
	
;void makeMove(game_state* board, player_move* pmove)
; Applies the move pmove on the game_state board
_makeMove:
.prolog:
	push		ebp
	mov		ebp, esp
	push		ebx
	push		esi
	push		edi
	
	; [ebp+8] = board
	mov		edi, [ebp+8]
	; [ebp+12] = pmove
	mov		esi, [ebp+8]
	
	; Make the move on the board
	; Start rank should be multiplied by 8, then add the start file to get the index of the square
	mov		eax, 0
	mov		ebx, 0
	
	mov		al, [esi + pm_start_file]
	push		eax
	mov		al, [esi + pm_start_rank]
	push		eax
	call		_toIndex
	add		esp, 8
	
	mov		bl, [edi + gs_board + eax]
	mov byte	[edi + gs_board + eax], 0x00
	
	mov		al, [esi + pm_destination_file]
	push		eax
	mov		al, [esi + pm_destination_rank]
	push		eax
	call		_toIndex
	add		esp, 8
	
	mov		[edi + gs_board + eax], bl
	
	; If it was a pawn move that went across two ranks, then the pawn moved twice and is a valid target for en passant
	mov		al, [esi + pm_piece]
	cmp		al, 'P'
	jne		.en_passant_skip
	mov		al, [esi + pm_destination_rank]
	sub		al, [esi + pm_start_rank]
	cmp		al, 2
	je		.en_passant_set
	cmp		al, -2
	je		.en_passant_set
	
	; If it gets here, there is no valid en passant so clear it from the game state
	mov byte	[edi + gs_passant_file], 0
	jmp		.en_passant_skip
	
.en_passant_set:
	mov		al, [esi + pm_start_file]
	mov		[edi + gs_passant_file], al
	
.en_passant_skip:	
	; Disable castling where applicable
	; If a start or destination file matches a corner, disable castling to that corner
	; TODO: This code does not account for a start position and destination position that each land on a corner
	mov		al, [esi + pm_start_rank]
	mov		ah, [esi + pm_start_file]
	cmp		ax, 'a1'
	je		.white_queenside
	cmp		ax, 'h1'
	je		.white_kingside
	cmp		ax, 'a8'
	je		.black_queenside
	cmp		ax, 'h8'
	je		.black_kingside
	
	mov		ah, [esi + pm_destination_rank]
	mov		al, [esi + pm_destination_file]
	cmp		ax, 'a1'
	je		.white_queenside
	cmp		ax, 'h1'
	je		.white_kingside
	cmp		ax, 'a8'
	je		.black_queenside
	cmp		ax, 'h8'
	je		.black_kingside
	
.white_queenside:
	mov byte	[edi + gs_wh_queenside], 0
	jmp		.white_castling
.white_kingside:
	mov byte	[edi + gs_wh_kingside], 0
	jmp		.white_castling
.black_queenside:
	mov byte	[edi + gs_bl_queenside], 0
	jmp		.white_castling
.black_kingside:
	mov byte	[edi + gs_bl_kingside], 0
	jmp		.white_castling
	
	; If the king is moved, disable all castling for that player
.white_castling:
	mov		al, [edi + gs_turn]
	cmp		al, 0x00
	jne		.black_castling
	mov		al, [esi + pm_piece]
	cmp		al, 'K'
	jne		.black_castling
	mov byte	[edi + gs_wh_queenside], 0
	mov byte	[edi + gs_wh_kingside], 0
	jmp		.castling_skip
.black_castling:
	mov		al, [edi + gs_turn]
	cmp		al, 0x01
	jne		.castling_skip
	mov		al, [esi + pm_piece]
	cmp		al, 'K'
	jne		.castling_skip
	mov byte	[edi + gs_bl_queenside], 0
	mov byte	[edi + gs_bl_kingside], 0

.castling_skip:
	
.epilog:
	pop		edi
	pop		esi
	pop		ebx
	pop		ebp
	
	ret