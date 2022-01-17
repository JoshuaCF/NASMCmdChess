def main():
	valid_promotions = ["Q", "R", "B", "N"]
	valid_pieces = ["K", "Q", "R", "B", "N"]
	
	with open("bin\\tests.txt", "w") as f:
		f.write("792\n")  # This will have to be changed as I add more tests. I'll probably compute this manually.
		
		# Castling test cases -- these are done manually
		# 8 test cases
		
		f.write("O-O\n")
		f.write("1\n")
		
		f.write("O-O-O\n")
		f.write("1\n")
		
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
		
		# Pawn move test cases
		file = ord("a")
		end_file = ord("h")+1
		
		for i in range(file, end_file):  # Loops 8 times
			for j in range(2, 8):  # Loops 6 times
				f.write(chr(i))
				f.write(f"{j}\n")
				f.write("1\n")
		
		# Pawn promotion test cases
		for i in range(file, end_file):  # Loops 8 times
			for j in valid_promotions:  # Loops 4 times, 2 cases each
				# Rank 1 promotions
				f.write(chr(i))
				f.write(f"1={j}\n")
				f.write("1\n")
				
				# Rank 8 promotions
				f.write(chr(i))
				f.write(f"8={j}\n")
				f.write("1\n")
				
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
			
		# Movements of all the pieces to any particular square, as well as captures at any particular square
		for piece in valid_pieces:  # Loops 5 times
			for i in range(file, end_file):  # Loops 8 times
				for j in range(1, 9):  # Loops 8 times, 2 cases each
					f.write(f"{piece}{chr(i)}{j}\n")
					f.write(f"1\n")
					
					f.write(f"{piece}x{chr(i)}{j}\n")
					f.write(f"1\n")


if __name__ == "__main__":
	main()