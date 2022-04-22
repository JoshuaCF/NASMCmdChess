%include "structs.asm"

	global		_checkMove
	global		_parseMove
	global		_completeMove
	global		_makeMove
	global		_printBoard
	global		_toIndex
	global		_copyBoard
	
	extern		_printf
	
	extern		_isCheck
	
	section		.data
king_pmove:					; Used with checking castling
istruc player_move

at pm_piece
	db		'K'
at pm_start_file
	db		'e'
at pm_start_rank
	db		0
at pm_destination_file
	db		0
at pm_destination_rank
	db		0
at pm_promotion
	db		0
at pm_castling
	db		0
	
iend
	
	section		.bss
board_bfr:
	resb		game_state_size

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
	
.body:	; Nothing jumps to this label, but it will get put as a symbol in the debug file. Helps for separating out the actual body of this subroutine from the prologue.
	mov		edi, [ebp+12]		; pmove ptr
	mov		ebx, [ebp+8]		; board ptr
	
	; If the move is castling, the checks are a bit different
	mov		al, [edi+pm_castling]
	cmp		al, 0
	je		.look_for_self_captures	; If castling != 0, then some castling checks need to be done
	
.validate_castling:
	; First ensure the king is not castling out of check
	push		ebx
	call		_isCheck
	add		esp, 4
	cmp		eax, 1
	je		.invalid_castling
	
	; Clone the board to board_bfr so we can move the king, then look for a check
	push		board_bfr
	push		ebx
	call		_copyBoard
	add		esp, 8
	
	; Combine gs_turn and pm_castling into a single unique value
	; This allows me to avoid nesting 'if statements', and I like that.
	mov		eax, 0
	mov		al, [ebx+gs_turn]
	shl		al, 2			; 0b00000000 if white, 0b00000100 if black
	or		al, [edi+pm_castling]	; 0b00000001 if white kingside, 0b00000010 if white queenside
						; 0b00000101 if black kingside, 0b00000110 if black queenside
	
	cmp		al, 0b00000001		; white kingside
	je		.wh_kingside
	cmp		al, 0b00000010		; white queenside
	je		.wh_queenside
	cmp		al, 0b00000101		; black kingside
	je		.bl_kingside
	cmp		al, 0b00000110		; black queenside
	je		.bl_queenside
	
.wh_kingside:
	; Check the flag to ensure it's valid
	mov		al, [ebx+gs_wh_kingside]
	cmp		al, 1
	jne		.invalid_castling
	
	; Ensure the spaces travelled across are empty (f1 and g1 for white kingside)
	; I could hardcode these indices, but if I ever change how the board is internally formatted, then they would change
	; So I'll just call _toIndex (plus that's easier to me lol)
	
	; Checking f1
	mov		eax, 0
	mov		al, 'f'
	push		eax
	mov		al, '1'
	push		eax
	call		_toIndex
	add		esp, 8
	
	mov		al, [ebx + gs_board + eax]
	cmp		al, 0x0
	jne		.invalid_castling
	
	; Checking g1
	mov		eax, 0
	mov		al, 'g'
	push		eax
	mov		al, '1'
	push		eax
	call		_toIndex
	add		esp, 8
	
	mov		al, [ebx + gs_board + eax]
	cmp		al, 0x0
	jne		.invalid_castling
	
	; Ensure the king is not moving through check (landing on check will be looked at later)
	mov byte	[king_pmove + pm_start_rank], '1'
	mov byte	[king_pmove + pm_destination_file], 'f'
	mov byte	[king_pmove + pm_destination_rank], '1'
	
	; Simulate the move
	push		king_pmove
	push		board_bfr
	call		_makeMove
	add		esp, 8
	
	; Query for checks on the king
	push		board_bfr
	call		_isCheck
	add		esp, 4
	
	; If one step over would leave the king in check, then you can not castle this way
	cmp		eax, 1
	je		.invalid_castling
	
	; If none of this fails, then move on to looking for a final check
	jmp		.look_for_check
	
.wh_queenside:
	; Check the flag to ensure it's valid
	mov		al, [ebx+gs_wh_queenside]
	cmp		al, 1
	jne		.invalid_castling
	
	; Ensure the spaces travelled across are empty (b1, c1 and d1 for white queenside)
	
	; Checking b1
	mov		eax, 0
	mov		al, 'b'
	push		eax
	mov		al, '1'
	push		eax
	call		_toIndex
	add		esp, 8
	
	mov		al, [ebx + gs_board + eax]
	cmp		al, 0x0
	jne		.invalid_castling
	
	; Checking c1
	mov		eax, 0
	mov		al, 'c'
	push		eax
	mov		al, '1'
	push		eax
	call		_toIndex
	add		esp, 8
	
	mov		al, [ebx + gs_board + eax]
	cmp		al, 0x0
	jne		.invalid_castling
	
	; Checking d1
	mov		eax, 0
	mov		al, 'd'
	push		eax
	mov		al, '1'
	push		eax
	call		_toIndex
	add		esp, 8
	
	mov		al, [ebx + gs_board + eax]
	cmp		al, 0x0
	jne		.invalid_castling
	
	; Ensure the king is not moving through check (landing on check will be looked at later)
	mov byte	[king_pmove + pm_start_rank], '1'
	mov byte	[king_pmove + pm_destination_file], 'd'
	mov byte	[king_pmove + pm_destination_rank], '1'
	
	; Simulate the move
	push		king_pmove
	push		board_bfr
	call		_makeMove
	add		esp, 8
	
	; Query for checks on the king
	push		board_bfr
	call		_isCheck
	add		esp, 4
	
	; If one step over would leave the king in check, then you can not castle this way
	cmp		eax, 1
	je		.invalid_castling
	
	; If none of this fails, then move on to looking for a final check
	jmp		.look_for_check
	
.bl_kingside:
	; Check the flag to ensure it's valid
	mov		al, [ebx+gs_bl_kingside]
	cmp		al, 1
	jne		.invalid_castling
	
	; Ensure the spaces travelled across are empty (f8 and g8 for black kingside)
	
	; Checking f8
	mov		eax, 0
	mov		al, 'f'
	push		eax
	mov		al, '8'
	push		eax
	call		_toIndex
	add		esp, 8
	
	mov		al, [ebx + gs_board + eax]
	cmp		al, 0x0
	jne		.invalid_castling
	
	; Checking g8
	mov		eax, 0
	mov		al, 'g'
	push		eax
	mov		al, '8'
	push		eax
	call		_toIndex
	add		esp, 8
	
	mov		al, [ebx + gs_board + eax]
	cmp		al, 0x0
	jne		.invalid_castling
	
	; Ensure the king is not moving through check (landing on check will be looked at later)
	mov byte	[king_pmove + pm_start_rank], '8'
	mov byte	[king_pmove + pm_destination_file], 'f'
	mov byte	[king_pmove + pm_destination_rank], '8'
	
	; Simulate the move
	push		king_pmove
	push		board_bfr
	call		_makeMove
	add		esp, 8
	
	; Query for checks on the king
	push		board_bfr
	call		_isCheck
	add		esp, 4
	
	; If one step over would leave the king in check, then you can not castle this way
	cmp		eax, 1
	je		.invalid_castling
	
	; If none of this fails, then move on to looking for a final check
	jmp		.look_for_check
	
.bl_queenside:
	; Check the flag to ensure it's valid
	mov		al, [ebx+gs_bl_queenside]
	cmp		al, 1
	jne		.invalid_castling
	
	; Ensure the spaces travelled across are empty (b8, c8 and d8 for black queenside)
	
	; Checking b8
	mov		eax, 0
	mov		al, 'b'
	push		eax
	mov		al, '8'
	push		eax
	call		_toIndex
	add		esp, 8
	
	mov		al, [ebx + gs_board + eax]
	cmp		al, 0x0
	jne		.invalid_castling
	
	; Checking c8
	mov		eax, 0
	mov		al, 'c'
	push		eax
	mov		al, '8'
	push		eax
	call		_toIndex
	add		esp, 8
	
	mov		al, [ebx + gs_board + eax]
	cmp		al, 0x0
	jne		.invalid_castling
	
	; Checking d8
	mov		eax, 0
	mov		al, 'd'
	push		eax
	mov		al, '8'
	push		eax
	call		_toIndex
	add		esp, 8
	
	mov		al, [ebx + gs_board + eax]
	cmp		al, 0x0
	jne		.invalid_castling
	
	; Ensure the king is not moving through check (landing on check will be looked at later)
	mov byte	[king_pmove + pm_start_rank], '8'
	mov byte	[king_pmove + pm_destination_file], 'd'
	mov byte	[king_pmove + pm_destination_rank], '8'
	
	; Simulate the move
	push		king_pmove
	push		board_bfr
	call		_makeMove
	add		esp, 8
	
	; Query for checks on the king
	push		board_bfr
	call		_isCheck
	add		esp, 4
	
	; If one step over would leave the king in check, then you can not castle this way
	cmp		eax, 1
	je		.invalid_castling
	
	; If none of this fails, then move on to looking for a final check
	jmp		.look_for_check

.look_for_self_captures:
	; If the destination square contains a piece that belongs to the current player, the move fails
	mov		eax, 0
	mov		al, [edi + pm_destination_file]
	push		eax
	mov		al, [edi + pm_destination_rank]
	push		eax
	call		_toIndex
	add		esp, 8
	
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
	; Copy the entire board over to a board buffer
	push		board_bfr
	mov		eax, [ebp+8]
	push		eax
	call		_copyBoard
	add		esp, 8
	
	; Make the potential move on the buffer board (don't swap the player turn! _isCheck looks for checks on the player whose turn it is)
	mov		eax, [ebp+12]
	push		eax
	push		board_bfr
	call		_makeMove
	add		esp, 8
	
	; Call _isCheck and check the result. If eax == 1, jmp to .invalid_in_check
	push		board_bfr
	call		_isCheck
	add		esp, 4
	cmp		eax, 0
	je		.valid
	jmp		.invalid_in_check

.invalid_castling:
	mov		eax, 1
	jmp		.epilog
	
.invalid_self_capture:
	mov		eax, 2
	jmp		.epilog
	
.invalid_in_check:
	mov		eax, 3
	jmp		.epilog

.valid:
	mov		eax, 0
	
.epilog:
	pop		edi
	pop		esi
	pop		ebx
	pop		ebp
	ret

	section		.bss
in_len:
	resd		1
fragments_parsed:
	; Tracks how many parts of a tile were parsed (1 means file or rank, but not both, 2 means both, 0 means none)
	resb		1
tiles_parsed:
	; The way I have this set up, you could just chain tiles together and it would only look at the last two
	; This will count how many times a tile got parsed. If it's at 2, it will stop parsing and consider the input invalid
	resb		1
	
	
	section		.text
; bool parseMove(char* input, player_move* pmove) -> returns whether or not parsing failed
_parseMove:
.prolog:
	push		ebp
	mov		ebp, esp
	push		ebx
	push		esi
	push		edi
	
.body:
	
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
	
	mov dword	[in_len], 0
	mov byte	[tiles_parsed], 0
	
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
.parse_piece:
	; Go through each character, determining its purpose and if its valid
	mov		ecx, 0			; Start on character 0
	
	; Check for special cases first
	mov		dl, [ebx+ecx]		; Current character (should always be the first character at this point)
	cmp		dl, 'O'			; If the input starts with this, jump to checking for special cases
	je		.special
	
	; The first character can always be used to determine what piece is being moved
	mov		al, [ebx+ecx]
	
	; Check for all pieces but a pawn
	cmp		al, 'K'
	je		.not_pawn
	cmp		al, 'Q'
	je		.not_pawn
	cmp		al, 'R'
	je		.not_pawn
	cmp		al, 'B'
	je		.not_pawn
	cmp		al, 'N'
	je		.not_pawn
	
	; If the first letter isn't a piece or castling, ensure it's 'a'-'h'
	cmp		al, 'a'
	jl		.invalid
	cmp		al, 'h'
	jg		.invalid
	
.pawn:
	mov byte	[edi + pm_piece], 'P'
	jmp		.clean_x
	
.not_pawn:
	mov		[edi + pm_piece], al
	inc		ecx
	
.clean_x:
	; Shave off any 'x' that might be at the start
	mov		al, [ebx + ecx]
	cmp		al, 'x'
	jne		.parse_destination
	
	inc		ecx
	
.parse_destination:
	; Clear the tile flag
	mov byte	[fragments_parsed], 0
	
	; Try parsing the next two characters into a tile
	mov		al, [ebx + ecx]
	
	; First character should be 'a'-'h'
	; If it fails, jump to .parse_disambiguation and attempt to resume from there
	; We could have a rank first for disambiguation
	cmp		al, 'a'
	jl		.parse_disambiguation
	cmp		al, 'h'
	jg		.parse_disambiguation
	
	mov		[edi + pm_destination_file], al
	mov byte	[fragments_parsed], 1
	
	inc		ecx
	
	; Attempt to read in a rank
	mov		al, [ebx + ecx]
	cmp		al, '1'
	jl		.parse_disambiguation
	cmp		al, '8'
	jg		.parse_disambiguation
	
	mov		[edi + pm_destination_rank], al
	
	inc		ecx
	
	; Mark that a tile has been parsed
	mov		al, [tiles_parsed]
	inc		al
	mov		[tiles_parsed], al
	
	; At this point, a tile is fully parsed, but it could actually be the disambiguation tile
	; Check to see if we're at the end of the string. If so, the move is valid and fully parsed
	cmp		ecx, [in_len]
	jge		.valid
	
	; Otherwise, check to see if there's an '=' for promotions
	mov		al, [ebx + ecx]
	cmp		al, '='
	je		.parse_promotion
	
	; If we've fully parsed a tile and we're not at the end of the string, and there's no promotion coming up next
	; Then what was parsed MUST be disambiguation, and there MUST be two characters of destination next
	; First check that we haven't already parsed a destination and disambiguation
	mov		al, [tiles_parsed]
	cmp		al, 2
	jge		.invalid
	
	; Copy the values to the correct spot, and try parsing the destination again
	mov		al, [edi + pm_destination_file]
	mov		[edi + pm_start_file], al
	
	mov		al, [edi + pm_destination_rank]
	mov		[edi + pm_start_rank], al
	
	jmp		.clean_x
	
.parse_disambiguation:
	; If it jumps here, then .parse_destination came across a character that didn't match the expected order
	; Go ahead and copy the file, in case one was read in
	mov		al, [edi + pm_destination_file]
	mov		[edi + pm_start_file], al
	
	; If a tile was already parsed and .parse_destination sends the execution here again, then the input is invalid
	mov		al, [tiles_parsed]
	cmp		al, 1
	jge		.invalid
	
	; If there's only a file for disambiguation, rank parsing will fail and the fragments will be looked at
	mov		al, [ebx + ecx]
	cmp		al, '1'
	jl		.disam_end
	cmp		al, '8'
	jg		.disam_end
	
	mov		[edi + pm_start_rank], al
	
	inc		ecx
	
	mov		al, [tiles_parsed]
	inc		al
	mov		[tiles_parsed], al
	
	jmp		.clean_x
	
.disam_end:
	; parse_destination came across something strange, and parse_disambiguation didn't find anything new. check to see if parse_destination found anything
	mov		al, [fragments_parsed]
	cmp		al, 0
	; If it didn't, then something is invalid
	je		.invalid
	
	mov		al, [tiles_parsed]
	inc		al
	mov		[tiles_parsed], al
	
	jmp		.clean_x
	
.parse_promotion:
	; Ensure that the move is a pawn move if we're here
	mov		al, [edi + pm_piece]
	cmp		al, 'P'
	jne		.invalid
	
	; The current character will be '=' if it gets here
	inc		ecx
	
	mov		al, [ebx + ecx]
	
	; Ensure the next character is an actual piece that can be a promotion piece
	cmp		al, 'Q'
	je		.promotion_end
	cmp		al, 'R'
	je		.promotion_end
	cmp		al, 'B'
	je		.promotion_end
	cmp		al, 'N'
	je		.promotion_end
	
	; If it wasn't one of those, then the input is invalid
	jmp		.invalid
	
.promotion_end:
	; Copy the promotion piece into the move pointer
	mov		[edi + pm_promotion], al
	
	; Ensure we're at the string end before jumping to .valid
	inc		ecx
	cmp		ecx, [in_len]
	je		.valid
	jmp		.invalid
	
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
	mov byte	[edi + pm_castling], 2	; castling=2 is queenside castling (it's okay if it jumps to invalid after this -- this will get ignored)
	je		.valid
	jmp		.invalid
.kingside:
	mov		dx, [ebx+1]
	cmp		dx, '-O'		; Same as above but with two characters
	mov byte	[edi + pm_castling], 1	; castling=1 is kingside castling
	je		.valid
	jmp		.invalid
	
	; An invalid input will jump here
.invalid:
	mov		eax, 0
	jmp		.epilog
	
	; A valid input will jump here
.valid:
	; There's still one final check to make. If the move is a pawn move, and no disambiguation file was specified
	; then the pawn must start on the same file as its ending file
	mov		al, [edi + pm_piece]
	cmp		al, 'P'
	jne		.valid_2
	
	mov		al, [edi + pm_start_file]
	cmp		al, 0x0
	jne		.valid_2
	
	mov		al, [edi + pm_destination_file]
	mov		[edi + pm_start_file], al
	
.valid_2:
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
; This value will be used for pawn movements. It represents what needs to be added to the rank to step a move 'backwards', relative to the player's perspective
backwards:
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
	
	; If the move is castling, then just return OK and let checkMove verify that the castling can be done.
	; I know this is a bit inconsistent... but whatever.
	mov		al, [edi + pm_castling]
	cmp		al, 0
	jne		.valid
	
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
	
.pawn:
	; Complete the match value
	or		ah, 0b00000001
	mov		[match_value], ah
	
.compute_backwards:
	; Compute a 'backwards' offset
	; gs_turn = 0 = white
	; gs_turn = 1 = black
	; White offset should be negative 1
	; Black offset should be positive 1
	; gs_turn << 1 == gs_turn * 2
	; gs_turn * 2 - 1 will give positive 1 for black, and negative 1 for white. No jumps required
	mov		al, [ebx+gs_turn]
	shl		al, 1
	sub		al, 1
	mov		[backwards], al
	
.pawn_move:
	; If the start file and the end file match, the pawn is moving one or two tiles
	mov		al, [edi+pm_destination_file]
	mov		ah, [edi+pm_start_file]
	cmp		al, ah
	jne		.pawn_capture
	
	; The destination square must be empty
	mov		eax, 0
	mov		al, [edi+pm_destination_file]
	push		eax
	mov		al, [edi+pm_destination_rank]
	push		eax
	
	call		_toIndex
	add		esp, 8
	
	mov		al, [ebx+gs_board+eax]
	cmp		al, 0x0
	jne		.err_no_piece		; I shoud probably write in a better error for this case, but eh.
	
.pawn_single_move:
	; First, ensure the tile is even on the board
	mov		al, [edi+pm_destination_rank]
	mov		ah, [backwards]
	add		al, ah
	cmp		al, '1'
	jl		.err_no_piece
	cmp		al, '8'
	jg		.err_no_piece
	
	mov		ecx, 0
	mov		cl, al
	mov		eax, 0
	mov		al, [edi+pm_destination_file]
	push		eax
	push		ecx
	
	call		_toIndex
	add		esp, 8
	
	; If one step backwards is NOT empty, add it to the list of tiles to check, and jump to .locate_matches
	; If it is empty, look for a double move possibility
	mov		al, [ebx+gs_board+eax]
	cmp		al, 0x0
	je		.pawn_double_move_check
	
	; The tile is not empty. Add it to the list of potential pieces, and go to .locate_matches
	mov		al, [edi+pm_destination_file]
	mov		[potential_pieces_arr], al
	
	mov		al, [edi+pm_destination_rank]
	mov		ah, [backwards]
	add		al, ah
	mov		[potential_pieces_arr + 1], al
	
	mov byte	[potential_pieces], 1
	jmp		.locate_matches
	
.pawn_double_move_check:
	; Ensure the tile two spaces back is on rank '2' or '7'
	mov		al, [edi+pm_destination_rank]
	mov		ah, [backwards]
	add		al, ah
	add		al, ah
	cmp		al, '2'
	je		.pawn_double_move
	cmp		al, '7'
	je		.pawn_double_move
	jmp		.err_no_piece
	
.pawn_double_move:
	; There's no need to check the state of the tile two steps back, .locate_matches will handle it
	mov		ah, [edi+pm_destination_file]
	mov		[potential_pieces_arr], ah
	mov		[potential_pieces_arr + 1], al
	mov byte	[potential_pieces], 1
	jmp		.locate_matches
	
.pawn_capture:
	; If the start file and end file do not match, the move must be a diagonal capture
	; Check to see if the destination is empty first. If it is, perform en passant checks
	mov		eax, 0
	mov		al, [edi+pm_destination_file]
	push		eax
	mov		al, [edi+pm_destination_rank]
	push		eax
	
	call		_toIndex
	add		esp, 8
	
	mov		al, [ebx+gs_board+eax]
	
	cmp		al, 0x0
	jne		.pawn_capture_final
	
.pawn_capture_en_passant:
	; If the destination is empty, then it can't be a capture unless it's en passant
	mov		al, [edi+pm_destination_file]
	mov		ah, [ebx+gs_passant_file]
	cmp		al, ah
	jne		.err_no_piece
	
	; The destination rank must also be '6' or '3' for en passant
	; 6 for white, 3 for black
	mov		al, [edi+pm_destination_rank]
	
	mov		cl, [ebx+gs_turn]
	cmp		cl, 0
	je		.pawn_white
	jmp		.pawn_black
	
.pawn_white:
	cmp		al, '6'
	je		.pawn_capture_final
	jmp		.err_no_piece
	
.pawn_black:
	cmp		al, '3'
	je		.pawn_capture_final
	jmp		.err_no_piece

.pawn_capture_final:
	; Add the two locations diagonally backwards to the tiles that should be checked
	mov		edx, 0
	mov		dl, [potential_pieces]
	
	mov		al, [edi+pm_destination_file]
	mov		ah, [edi+pm_destination_rank]
	mov		cl, [backwards]
	add		ah, cl
	
	cmp		ah, '1'
	jl		.err_no_piece
	cmp		ah, '8'
	jg		.err_no_piece
	
	add		al, -1
	cmp		al, 'a'
	jl		.pawn_capture_final_2
	cmp		al, 'h'
	jg		.pawn_capture_final_2
	
	mov		[potential_pieces_arr + edx*2], al
	mov		[potential_pieces_arr + edx*2 + 1], ah
	inc		dl
	mov		[potential_pieces], dl
	
.pawn_capture_final_2:
	add		al, 2
	cmp		al, 'a'
	jl		.locate_matches
	cmp		al, 'h'
	jg		.locate_matches
	
	mov		[potential_pieces_arr + edx*2], al
	mov		[potential_pieces_arr + edx*2 + 1], ah
	inc		dl
	mov		[potential_pieces], dl
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
	
	section		.text
	
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
	
.body:
	; [ebp+8] = board
	mov		edi, [ebp+8]
	; [ebp+12] = pmove
	mov		esi, [ebp+12]
	
	; If castling != 0, then the move has special rules
	mov		eax, 0
	mov		al, [esi + pm_castling]
	cmp		al, 0
	jne		.castling
	jmp		.normal_move
	
.castling:
	; Mark the king as the piece being moved in the move buffer
	; This is an easy way to disable all castling for this player's king by acting as if the king moved
	mov byte	[esi + pm_piece], 'K'
	
	; Combine gs_turn and pm_castling into a single unique value
	; This allows me to avoid nesting 'if statements', and I like that.
	mov		eax, 0
	mov		al, [edi + gs_turn]
	shl		al, 2			; 0b00000000 if white, 0b00000100 if black
	or		al, [esi + pm_castling]	; 0b00000001 if white kingside, 0b00000010 if white queenside
						; 0b00000101 if black kingside, 0b00000110 if black queenside
	cmp		al, 0b00000001
	je		.wh_kingside
	cmp		al, 0b00000010
	je		.wh_queenside
	cmp		al, 0b00000101
	je		.bl_kingside
	cmp		al, 0b00000110
	je		.bl_queenside
	
.wh_kingside:
	;		King goes from e1 to g1, rook goes from h1 to f1
	;		Zero out e1 and h1, put 0x60 on g1 and 0x48 on f1
	mov		eax, 0
	mov		al, 'e'
	push		eax
	mov		al, '1'
	push		eax
	call		_toIndex
	add		esp, 8
	mov byte	[edi + gs_board + eax], 0x0
	
	mov		eax, 0
	mov		al, 'h'
	push		eax
	mov		al, '1'
	push		eax
	call		_toIndex
	add		esp, 8
	mov byte	[edi + gs_board + eax], 0x0
	
	mov		eax, 0
	mov		al, 'g'
	push		eax
	mov		al, '1'
	push		eax
	call		_toIndex
	add		esp, 8
	mov byte	[edi + gs_board + eax], 0x60
	
	mov		eax, 0
	mov		al, 'f'
	push		eax
	mov		al, '1'
	push		eax
	call		_toIndex
	add		esp, 8
	mov byte	[edi + gs_board + eax], 0x48
	
	; Jump to the section that handles the disabling of castling for a king move
	; (As a shortcut, we can treat castling as a king move to disable all further castling)
	jmp		.white_castling
	
.wh_queenside:
	;		King goes from e1 to c1, rook goes from a1 to d1
	;		Zero out e1 and a1, put 0x60 on c1 and 0x48 on d1
	mov		eax, 0
	mov		al, 'e'
	push		eax
	mov		al, '1'
	push		eax
	call		_toIndex
	add		esp, 8
	mov byte	[edi + gs_board + eax], 0x0
	
	mov		eax, 0
	mov		al, 'a'
	push		eax
	mov		al, '1'
	push		eax
	call		_toIndex
	add		esp, 8
	mov byte	[edi + gs_board + eax], 0x0
	
	mov		eax, 0
	mov		al, 'c'
	push		eax
	mov		al, '1'
	push		eax
	call		_toIndex
	add		esp, 8
	mov byte	[edi + gs_board + eax], 0x60
	
	mov		eax, 0
	mov		al, 'd'
	push		eax
	mov		al, '1'
	push		eax
	call		_toIndex
	add		esp, 8
	mov byte	[edi + gs_board + eax], 0x48
	
	; Jump to the section that handles the disabling of castling for a king move
	; (As a shortcut, we can treat castling as a king move to disable all further castling)
	jmp		.white_castling
	
.bl_kingside:
	;		King goes from e8 to g8, rook goes from h8 to f8
	;		Zero out e8 and h8, put 0xA0 on g8 and 0x88 on f8
	mov		eax, 0
	mov		al, 'e'
	push		eax
	mov		al, '8'
	push		eax
	call		_toIndex
	add		esp, 8
	mov byte	[edi + gs_board + eax], 0x0
	
	mov		eax, 0
	mov		al, 'h'
	push		eax
	mov		al, '8'
	push		eax
	call		_toIndex
	add		esp, 8
	mov byte	[edi + gs_board + eax], 0x0
	
	mov		eax, 0
	mov		al, 'g'
	push		eax
	mov		al, '8'
	push		eax
	call		_toIndex
	add		esp, 8
	mov byte	[edi + gs_board + eax], 0xA0
	
	mov		eax, 0
	mov		al, 'f'
	push		eax
	mov		al, '8'
	push		eax
	call		_toIndex
	add		esp, 8
	mov byte	[edi + gs_board + eax], 0x88
	
	; Jump to the section that handles the disabling of castling for a king move
	; (As a shortcut, we can treat castling as a king move to disable all further castling)
	jmp		.white_castling
	
.bl_queenside:
	;		King goes from e8 to c8, rook goes from a8 to d8
	;		Zero out e8 and a8, put 0xA0 on c8 and 0x88 on d8
	mov		eax, 0
	mov		al, 'e'
	push		eax
	mov		al, '8'
	push		eax
	call		_toIndex
	add		esp, 8
	mov byte	[edi + gs_board + eax], 0x0
	
	mov		eax, 0
	mov		al, 'a'
	push		eax
	mov		al, '8'
	push		eax
	call		_toIndex
	add		esp, 8
	mov byte	[edi + gs_board + eax], 0x0
	
	mov		eax, 0
	mov		al, 'c'
	push		eax
	mov		al, '8'
	push		eax
	call		_toIndex
	add		esp, 8
	mov byte	[edi + gs_board + eax], 0xA0
	
	mov		eax, 0
	mov		al, 'd'
	push		eax
	mov		al, '8'
	push		eax
	call		_toIndex
	add		esp, 8
	mov byte	[edi + gs_board + eax], 0x88
	
	; Jump to the section that handles the disabling of castling for a king move
	; (As a shortcut, we can treat castling as a king move to disable all further castling)
	jmp		.white_castling

.normal_move:
	; Track whether or not the destination is empty (for use if the move was an en passant capture)
	mov		eax, 0
	mov		al, [esi+pm_destination_file]
	push		eax
	mov		al, [esi+pm_destination_rank]
	push		eax
	
	call		_toIndex
	add		esp, 8
	
	mov		al, [edi+gs_board+eax]
	push		eax			; Save the tile's contents to the stack
	
	; Make the move on the board
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
	
	pop		ecx			; Get the original contents of the destination tile
	
	; If it was a pawn move that went across two ranks, then the pawn moved twice and is a valid target for en passant
	mov		al, [esi + pm_piece]
	cmp		al, 'P'
	jne		.en_passant_unset
	mov		al, [esi + pm_destination_rank]
	sub		al, [esi + pm_start_rank]
	cmp		al, 2
	je		.en_passant_set
	cmp		al, -2
	je		.en_passant_set
	
.en_passant_unset:
	; If it gets here, there is no valid en passant so clear it from the game state
	mov byte	[edi + gs_passant_file], 0
	jmp		.en_passant_capture
	
.en_passant_set:
	mov		al, [esi + pm_start_file]
	mov		[edi + gs_passant_file], al
	
.en_passant_capture:
	; If the move was a pawn move that ended on a new file, and the destination was empty, clear the contents of the tile one 'backwards' move from the destination
	mov		al, [esi+pm_piece]
	cmp		al, 'P'
	jne		.en_passant_skip
	
	cmp		cl, 0x0
	jne		.en_passant_skip
	
	; Compute a 'backwards' offset
	; gs_turn = 0 = white
	; gs_turn = 1 = black
	; White offset should be negative 1
	; Black offset should be positive 1
	; gs_turn << 1 == gs_turn * 2
	; gs_turn * 2 - 1 will give positive 1 for black, and negative 1 for white. No jumps required
	mov		al, [edi+gs_turn]
	shl		al, 1
	sub		al, 1
	mov		[backwards], al
	
	mov		ecx, 0
	mov		cl, [esi+pm_destination_file]
	push		ecx
	mov		cl, [esi+pm_destination_rank]
	add		cl, al
	push		ecx
	
	call		_toIndex
	add		esp, 8
	
	mov byte	[edi+gs_board+eax], 0x00
	
.en_passant_skip:
	; Disable castling where applicable
	; If a start or destination file matches a corner, disable castling to that corner
	
	mov		eax, 0
	mov		al, [esi + pm_start_file]
	mov		ah, [esi + pm_start_rank]
	mov		ecx, 0
	mov		cl, [esi + pm_destination_file]
	mov		ch, [esi + pm_destination_rank]
	
	; Checks
.a1check:
	cmp		ax, 'a1'
	je		.a1
	cmp		cx, 'a1'
	je		.a1
.h1check:
	cmp		ax, 'h1'
	je		.h1
	cmp		cx, 'h1'
	je		.h1
.a8check:
	cmp		ax, 'a8'
	je		.a8
	cmp		cx, 'a8'
	je		.a8
.h8check:
	cmp		ax, 'h8'
	je		.h8
	cmp		cx, 'h8'
	je		.h8
	jmp		.white_castling
	
.a1:	; a1 corner
	mov byte	[edi + gs_wh_queenside], 0
	jmp		.h1check
.h1:	; h1 corner
	mov byte	[edi + gs_wh_kingside], 0
	jmp		.a8check
.a8:	; a8 corner
	mov byte	[edi + gs_bl_queenside], 0
	jmp		.h8check
.h8:	; h8 corner
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
	jmp		.epilog
.black_castling:
	mov		al, [edi + gs_turn]
	cmp		al, 0x01
	jne		.epilog
	mov		al, [esi + pm_piece]
	cmp		al, 'K'
	jne		.epilog
	mov byte	[edi + gs_bl_queenside], 0
	mov byte	[edi + gs_bl_kingside], 0
	
.epilog:
	pop		edi
	pop		esi
	pop		ebx
	pop		ebp
	
	ret
	
; copyBoard(game_state* board1, game_state* board2)
; Copies the entirety of board1 into board2
_copyBoard:
.prolog:
	push		ebp
	mov		ebp, esp
	push		ebx
	
.body:
	mov		ebx, [ebp+8]		; board1
	mov		edx, [ebp+12]		; board2
	
	mov		ecx, 0			; loop counter
.copy_board_loop:
	mov		al, [ebx + ecx]		; move value from board1 into al
	mov		[edx + ecx], al		; move value from al to board2
	
	inc		ecx
	cmp		ecx, game_state_size
	jl		.copy_board_loop
	
.epilog:
	pop		ebx
	pop		ebp
	
	ret