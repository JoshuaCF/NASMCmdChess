; This file will contain a variety of functions to verify that other functions are working
	global		_verify
	
	extern		_checkMove
	
	extern		_printf
	extern		_fopen
	extern		_fclose
	extern		_feof
	extern		_fscanf
	
	section		.code
checkMove_failed:
	db		"checkMove returned %d for %s. It should have been %d", 0xD, 0xA, 0x0
test_fmt:
	db		"%s", 0x0
num_fmt:
	db		"%d", 0x0
file_name:
	db		"tests.txt", 0x0
file_perms:
	db		"r", 0x0

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
	
	; The first set of tests are for checkMove, read how many tests there are
	push		num_tests
	push		num_fmt
	push dword	[file_handle]
	call		_fscanf
	add		esp, 12
	
	mov		ebx, 0
.checkMove_loop:
	; Loop for as many tests as there are, reading the tests and checking them
	cmp		ebx, [num_tests]
	jge		.checkMove_loop_end
	
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
	
	push dword	[expected_bfr]		; expected_bfr will be used for many different things -- in this case, it stores an integer, so it makes sense to pass by value
	push		test_bfr
	push		0
	call		_verify_checkMove
	add		esp, 12
	
	inc		ebx
	jmp		.checkMove_loop
.checkMove_loop_end:
	
.epilog:
	push dword	[file_handle]
	call		_fclose
	add		esp, 4
	
	pop		edi
	pop		esi
	pop		ebx
	
	ret

; bool verify_checkMove(boardState* board, char* input, int expected)
_verify_checkMove:
.prolog:
	push		ebp
	mov		ebp, esp
	
	push dword	[ebp+12]
	push dword	[ebp+8]
	call		_checkMove
	add		esp, 8
	
	cmp		eax, [ebp+16]
	je		.epilog
	
	push dword	[ebp+16]
	push dword	[ebp+12]
	push		eax
	push		checkMove_failed
	call		_printf
	add		esp, 16
	
.epilog:
	pop		ebp
	ret