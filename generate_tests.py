def main():
	valid_promotions = ["Q", "R", "B", "N"]
	valid_pieces = ["K", "Q", "R", "B", "N"]
	
	with open("bin\\tests.txt", "w") as f:
		f.write("38\n")  # Start off with invalid input format tests
		
		# Invalid castling tests (6 cases)
		
		f.write("O-O-P\n")
		f.write("0\n")
		
		f.write("OOOOP\n")
		f.write("0\n")
		
		f.write("OOP\n")
		f.write("0\n")
		
		f.write("OOOP\n")
		f.write("0\n")
		
		f.write("OP\n")
		f.write("0\n")
		
		f.write("O\n")
		f.write("0\n")
		
		file = ord("a")
		end_file = ord("h")+1
				
		# Invalid pawn test cases
		# 9th and 0th rank movements
		for i in range(file, end_file):  # Loops 8 times, 2 cases each
			f.write(chr(i))
			f.write("0\n")
			f.write("0\n")
			
			f.write(chr(i))
			f.write("9\n")
			f.write("0\n")
		
		# z and k file movements
		for i in range(1, 9): # Loops 8 times, 2 cases each
			f.write(f"k{i}\n")
			f.write("0\n")
			
			f.write(f"z{i}\n")
			f.write("0\n")
			
		# Move on to valid moves, and check that the individual components are parsed properly
		f.write("754\n")
		
		# Validation:
		# eax = 1 (implied)
		# piece
		# start_file
		# start_rank
		# destination_file
		# destination_rank
		# promotion
		# castling (0=no, 1=kingside, 2=queenside)
		
		# Valid castling tests (2 cases)
		
		f.write("O-O\n")
		f.write(f"{chr(0)}\n")  # This is ugly, but since this is going to be read as characters I need to write null characters
		f.write(f"{chr(0)}\n")
		f.write(f"{chr(0)}\n")
		f.write(f"{chr(0)}\n")
		f.write(f"{chr(0)}\n")
		f.write(f"{chr(0)}\n")
		f.write("1\n")
		
		f.write("O-O-O\n")
		f.write(f"{chr(0)}\n")
		f.write(f"{chr(0)}\n")
		f.write(f"{chr(0)}\n")
		f.write(f"{chr(0)}\n")
		f.write(f"{chr(0)}\n")
		f.write(f"{chr(0)}\n")
		f.write("2\n")
		
		# Pawn move test cases
		for i in range(file, end_file):  # Loops 8 times
			for j in range(2, 8):  # Loops 6 times
				f.write(chr(i))
				f.write(f"{j}\n")
				f.write("P\n")
				f.write(f"{chr(i)}\n")
				f.write(f"{chr(0)}\n")
				f.write(f"{chr(i)}\n")
				f.write(f"{j}\n")
				f.write(f"{chr(0)}\n")
				f.write("0\n")
				
		
		# Pawn promotion test cases
		for i in range(file, end_file):  # Loops 8 times
			for j in valid_promotions:  # Loops 4 times, 2 cases each
				# Rank 1 promotions
				f.write(chr(i))
				f.write(f"1={j}\n")
				f.write("P\n")
				f.write(f"{chr(i)}\n")
				f.write(f"{chr(0)}\n")
				f.write(f"{chr(i)}\n")
				f.write("1\n")
				f.write(f"{j}\n")
				f.write("0\n")
				
				# Rank 8 promotions
				f.write(chr(i))
				f.write(f"8={j}\n")
				f.write("P\n")
				f.write(f"{chr(i)}\n")
				f.write(f"{chr(0)}\n")
				f.write(f"{chr(i)}\n")
				f.write("8\n")
				f.write(f"{j}\n")
				f.write("0\n")
			
		# Movements of all the pieces to any particular square, as well as captures at any particular square
		for piece in valid_pieces:  # Loops 5 times
			for i in range(file, end_file):  # Loops 8 times
				for j in range(1, 9):  # Loops 8 times, 2 cases each
					f.write(f"{piece}{chr(i)}{j}\n")
					f.write(f"{piece}\n")
					f.write(f"{chr(0)}\n")
					f.write(f"{chr(0)}\n")
					f.write(f"{chr(i)}\n")
					f.write(f"{j}\n")
					f.write(f"{chr(0)}\n")
					f.write("0\n")
					
					f.write(f"{piece}x{chr(i)}{j}\n")
					f.write(f"{piece}\n")
					f.write(f"{chr(0)}\n")
					f.write(f"{chr(0)}\n")
					f.write(f"{chr(i)}\n")
					f.write(f"{j}\n")
					f.write(f"{chr(0)}\n")
					f.write("0\n")


if __name__ == "__main__":
	main()