%include "structs.asm"

	global		_isCheck
	global		_isStalemate
	global		_isCheckmate
	
	section		.data
	
	section		.bss
	
	section		.text
;bool isCheck(*game_state board) -> returns whether or not it is check for the current player's turn
_isCheck:
.prolog:
	push		ebp
	mov		ebp, esp
	
	; ebp + 8 = *game_state board
	mov		eax, 0			; TEMP
	
.epilog:
	pop		ebp
	
	ret

;bool legalMoveExists(*game_state board) - returns whether or not the current player is able to make a legal move
_legalMoveExists:
.prolog:
	push		ebp
	mov		ebp, esp
	
	; ebp + 8 = *game_state board
	mov		eax, 1			; TEMP
	
.epilog:
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