; r n b q k b n r
; p p p p p p p p
; ░ ░ ░ ░ ░ ░ ░ ░		
; ░ ░ ░ ░ ░ ░ ░ ░
; ░ ░ ░ ░ ░ ░ ░ ░ 
; ░ ░ ░ ░ ░ ░ ░ ░ 
; P P P P P P P P
; R N B Q K B N R

%ifndef structsasm
%define structsasm

struc game_state

; Whose turn is it
gs_turn:
	resb		1		; 0 = white, 1 = black
; 4 boolean values for whether or not castling is valid
gs_bl_kingside:
	resb		1
gs_wh_kingside:
	resb		1
gs_bl_queenside:
	resb		1
gs_wh_queenside:
	resb		1
gs_passant_file:
	resb		1		; If a pawn moved twice, this will be set to the file where this happened. En passant is valid for the next turn only.
; a1, b1, c1... a2, b2, c2... f8, g8, h8

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

; White pieces
; 0x60 = King
; 0x50 = Queen
; 0x48 = Rook
; 0x44 = Bishop
; 0x42 = Knight
; 0x41 = Pawn

; Black pieces
; 0xA0 = King
; 0x90 = Queen
; 0x88 = Rook
; 0x84 = Bishop
; 0x82 = Knight
; 0x81 = Pawn
gs_board:
	resb		64

endstruc

struc player_move

pm_piece:	
	resb		1
pm_start_file:
	resb		1
pm_start_rank:
	resb		1
pm_destination_file:
	resb		1
pm_destination_rank:
	resb		1
pm_promotion:
	resb		1
pm_castling:
	resb		1
	
endstruc

%endif