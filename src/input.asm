; This file will be responsible for ensuring that a listed move is valid algebraic chess notation
; and that it can be made with the current board state
	global		_checkMove
	
	section		.bss
in_len:
	resd		1
piece:	
	resb		1
start_file:
	resb		1
start_rank:
	resb		1
destination_file:
	resb		1
destination_rank:
	resb		1
promotion:
	resb		1
castling:
	resb		1

	section		.text
; bool checkMove(boardState* board, char* input)
_checkMove:
.prolog:
	push		ebp
	mov		ebp, esp
	; [ebp + 8] = arg 1
	; [ebp + 12] = arg 2
	push		ebx
	push		esi
	push		edi
	
	; Parse the text into its components
	push dword	[ebp+12]
	call		_parseMove
	add		esp, 4
	
	; If parseMove returns 0 in EAX, then the text is improperly formatted
	cmp		eax, 0
	je		.epilog
	
.epilog:
	pop		edi
	pop		esi
	pop		ebx
	pop		ebp
	ret

; bool parseMove(char* input) -> returns whether or not parsing failed
_parseMove:
.prolog:
	push		ebp
	mov		ebp, esp
	push		ebx
	push		esi
	push		edi

	mov byte	[piece], 0
	mov byte	[start_file], 0
	mov byte	[start_rank], 0
	mov byte	[destination_file], 0
	mov byte	[destination_rank], 0
	mov byte	[promotion], 0
	
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
	mov byte	[piece], dl
	inc		ecx
	
	jmp		.parseDisambiguation
	
.pawn:
	; If we get here, it's definitely a pawn move, starting on the file of this character
	; We can go ahead and do disambiguation stuff since pawns are a little weird
	mov byte	[piece], 'P'
	mov byte	[start_file], dl
	
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
	mov		[start_file], dl
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
	mov		[start_rank], dl
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
	
	mov		[destination_file], dl
	
	; Checking 1-8 for rank
	inc		ecx
	
	mov		dl, [ebx+ecx]
	
	cmp		dl, '1'
	jl		.invalid
	cmp		dl, '8'
	jg		.invalid
	
	mov		[destination_rank], dl
	
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
	mov		dl, [piece]
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
	
	mov		[promotion], dl
	jmp		.valid
.promotionSkip1:
	cmp		dl, 'R'
	jne		.promotionSkip2
	
	mov		[promotion], dl
	jmp		.valid
.promotionSkip2:
	cmp		dl, 'B'
	jne		.promotionSkip3
	
	mov		[promotion], dl
	jmp		.valid
.promotionSkip3:
	cmp		dl, 'N'
	jne		.invalid		; If we're checking for the last valid character and it doesn't match, then it's invalid
	
	mov		[promotion],dl
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
	mov byte	[castling], 2		; castling=2 is queenside castling (it's okay if it jumps to invalid after this -- this will get ignored)
	je		.valid
	jmp		.invalid
.kingside:
	mov		dx, [ebx+1]
	cmp		dx, '-O'		; Same as above but with two characters
	mov byte	[castling], 1		; castling=1 is kingside castling
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