struct pm {
	char piece;
	char start_file;
	char start_rank;
	char destination_file;
	char destination_rank;
	char promotion;
	char castling;
};

struct gs {
	char turn;
	char bl_kingside;
	char wh_kingside;
	char bl_queenside;
	char wh_queenside;
	char passant_file;
	char board[64];
};

struct pm pm_dummy;
struct gs gs_dummy;