; This file will contain a variety of functions to verify that other functions are working
%include "structs.asm"

	global		_verify
	
	extern		_checkMove
	
	extern		_printf
	extern		_fopen
	extern		_fclose
	extern		_fscanf
	
	section		.data
checkMove_failed:
	db		"checkMove returned %d for %s. It should have been %d", 0xD, 0xA, 0x0
piece_failed:
	db		"checkMove returned the piece %c for %s. It should have been %c", 0xD, 0xA, 0x0
start_file_failed:
	db		"checkMove returned the start file %c for %s. It should have been %c", 0xD, 0xA, 0x0
start_rank_failed:
	db		"checkMove returned the start rank %c for %s. It should have been %c", 0xD, 0xA, 0x0
destination_file_failed:
	db		"checkMove returned the destination file %c for %s. It should have been %c", 0xD, 0xA, 0x0
destination_rank_failed:
	db		"checkMove returned the destination rank %c for %s. It should have been %c", 0xD, 0xA, 0x0
promotion_failed:
	db		"checkMove returned the promotion %c for %s. It should have been %c", 0xD, 0xA, 0x0
castling_failed:
	db		"checkMove returned castling state %d for %s. It should have been %d", 0xD, 0xA, 0x0
test_fmt:
	db		"%s", 0x0
num_fmt:
	db		"%d", 0x0
move_fmt:
	db		"%7c", 0x0
one_char_fmt:
	db		"%1c", 0x0
file_name:
	db		"tests.txt", 0x0
file_perms:
	db		"r", 0x0
pmove_ptr:
istruc player_move

	at pm_piece
	db		0
	at pm_start_file
	db		0
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
test_bfr:
	resb		256
expected_bfr:
	resb		256
num_tests:
	resd		1
file_handle:
	resd		1

	section		.text
_verify:
.prolog:
	push		ebx
	push		esi
	push		edi
	
	; Open the file of test inputs
	push		file_perms
	push		file_name
	call		_fopen
	add		esp, 8
	
	mov		[file_handle], eax
	
	; The first set of tests are for failed checkMoves, read how many tests there are
	push		num_tests
	push		num_fmt
	push dword	[file_handle]
	call		_fscanf
	add		esp, 12
	
	mov		ebx, 0
.checkMove_fail_loop:
	; Loop for as many tests as there are, reading the tests and checking them
	cmp		ebx, [num_tests]
	jge		.checkMove_fail_loop_end
	
	push		test_bfr
	push		test_fmt
	push dword	[file_handle]
	call		_fscanf
	add		esp, 12
	
	push		expected_bfr
	push		num_fmt
	push dword	[file_handle]
	call		_fscanf
	add		esp, 12
	
	push dword	0
	push		test_bfr
	push		0
	push		0
	call		_verify_checkMove
	add		esp, 16
	
	inc		ebx
	jmp		.checkMove_fail_loop
.checkMove_fail_loop_end:

	; The next set of tests are for successful moves, so we'll also have to check that it gets parsed properly
	push		num_tests
	push		num_fmt
	push dword	[file_handle]
	call		_fscanf
	add		esp, 12
	
	mov		ebx, 0
.checkMove_success_loop:
	; Loop for as many tests as there are, reading the tests and checking them
	cmp		ebx, [num_tests]
	jge		.checkMove_success_loop_end
	
	push		test_bfr
	push		test_fmt
	push dword	[file_handle]
	call		_fscanf
	add		esp, 12

	; There's still a newline left over, so read that in to clean it up
	push		expected_bfr
	push		one_char_fmt
	push dword	[file_handle]
	call		_fscanf
	add		esp, 12
	
	push		expected_bfr
	push		move_fmt
	push dword	[file_handle]
	call		_fscanf
	add		esp, 12
	
	push		expected_bfr
	push dword	1
	push		test_bfr
	push		pmove_ptr
	push		0
	call		_verify_checkMove
	add		esp, 20
	
	inc		ebx
	jmp		.checkMove_success_loop

.checkMove_success_loop_end:
	
.epilog:
	push dword	[file_handle]
	call		_fclose
	add		esp, 4
	
	pop		edi
	pop		esi
	pop		ebx
	
	ret

; bool verify_checkMove(boardState* board, player_move* pmove, char* input, int expected_ret, [player_move* expected_move])
; Last argument only necessary if pmove is not null
_verify_checkMove:
.prolog:
	push		ebp
	mov		ebp, esp
	push		ebx
	push		esi
	
	push dword	[ebp+16]
	push dword	[ebp+12]
	push dword	[ebp+8]
	call		_checkMove
	add		esp, 12
	
	cmp		eax, [ebp+20]
	je		.verify_components
	
	push dword	[ebp+20]
	push dword	[ebp+16]
	push		eax
	push		checkMove_failed
	call		_printf
	add		esp, 16
	jmp		.epilog
	
.verify_components:
	; If a player_move pointer was provided as an argument, verify that it has the correct values
	cmp dword	[ebp+12], 0
	je		.epilog
	
	mov		ebx, [ebp+24]		; ebx now contains the pointer to what should be the correct moves
	mov		esi, [ebp+12]		; esi contains the pointer to what was actually returned
	
	; Compare each component and print out if it is incorrect
.piece:
	mov		eax, 0
	mov		edx, 0
	mov		al, [ebx+pm_piece]
	mov		dl, [esi+pm_piece]
	cmp		al, dl			; All this extra stuff just makes printing errors look a little nicer in code
	je		.start_file
	
	push		eax
	push dword	[ebp+16]
	push		edx
	push		piece_failed
	call		_printf
	add		esp, 16
	
.start_file:
	mov		eax, 0
	mov		edx, 0
	mov		al, [ebx+pm_start_file]
	mov		dl, [esi+pm_start_file]
	cmp		al, dl
	je		.start_rank
	
	push		eax
	push dword	[ebp+16]
	push		edx
	push		start_file_failed
	call		_printf
	add		esp, 16
	
.start_rank:
	mov		eax, 0
	mov		edx, 0
	mov		al, [ebx+pm_start_rank]
	mov		dl, [esi+pm_start_rank]
	cmp		al, dl
	je		.destination_file
	
	push		eax
	push dword	[ebp+16]
	push		edx
	push		start_rank_failed
	call		_printf
	add		esp, 16
	
.destination_file:
	mov		eax, 0
	mov		edx, 0
	mov		al, [ebx+pm_destination_file]
	mov		dl, [esi+pm_destination_file]
	cmp		al, dl
	je		.destination_rank
	
	push		eax
	push dword	[ebp+16]
	push		edx
	push		destination_file_failed
	call		_printf
	add		esp, 16
	
.destination_rank:
	mov		eax, 0
	mov		edx, 0
	mov		al, [ebx+pm_destination_rank]
	mov		dl, [esi+pm_destination_rank]
	cmp		al, dl
	je		.promotion
	
	push		eax
	push dword	[ebp+16]
	push		edx
	push		destination_rank_failed
	call		_printf
	add		esp, 16
	
.promotion:
	mov		eax, 0
	mov		edx, 0
	mov		al, [ebx+pm_promotion]
	mov		dl, [esi+pm_promotion]
	cmp		al, dl
	je		.castling
	
	push		eax
	push dword	[ebp+16]
	push		edx
	push		promotion_failed
	call		_printf
	add		esp, 16
	
.castling:
	mov		eax, 0
	mov		edx, 0
	mov		al, [ebx+pm_castling]
	mov		dl, [esi+pm_castling]
	cmp		al, dl
	je		.epilog
	
	push		eax
	push dword	[ebp+16]
	push		edx
	push		castling_failed
	call		_printf
	add		esp, 16
	
.epilog:
	pop		esi
	pop		ebx
	pop		ebp
	ret