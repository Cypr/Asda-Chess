/* **************************KINGSMEN CHESS********************************* */
/*                     -A Beginning Project in C/C++                         */
/* Jeremy Wurbs                                                              */
/* 1.12.2013                                                                 */
/*                                                                           */
/* About this program:
         The foundations for this project were laid down in 2009 as a beginning 
		 project in C. Some years later I've decided to reuse this project as
		 a project for C++ with opencv. 
   
   About Adrastos:
         Adrastos means "not inclined to run away" (Greek) and was the name of 
         a king of Argos in Greek legend. The current plan (if it has not been
         done yet) is to get Adrastos up and running under a normal negamax
         algorithm with a reasonable search depth and then start toying with 
         different learning algorithms.                                       */ 


/* Progress History: 
   
   Summer 2009
   v0.01:  Generates board
   v0.02:  Takes human input and updates board accordingly
   v0.1:   Human v. Human Capability, illegal input checks but no illegal move checks in place
   v0.2:   General off-board detection and move check detection for giving a legal move list
   v0.3:   AI Adrastos now available to play against. He takes the list of legal moves and chooses a random one.  
   v0.31:  Castling added to the legal move list (castling is now possible)
   
   Spring 2013
   v0.4:   Overhaul to c++ complete. 
			- GUI implemented that handles drag-n-drop piece placement. 
			- Reimplemented the following features:
				- Human v human capability
				- Legal move check (almost) complete, including castling
				- Adrastos will select a random move off the legal moves list
			- Undo last move function implemented
			- In-check testing implemented
			- Lazy evaluation using material and individual piece square tables implemented

   Still to come:
         Finish making the entire game completely rulebook legit
         - add check and check mate testing
         - add en passant
         - add pawn promotion
         - add testing to make sure king doesn't move into or through check while castling
         Complete the basic Adrastos AI structure
         - add deeper analysis function
         - add negamax
         - add alpha/beta pruning
         - add trasplantation table capabilities (hash tables of all considered moves)

	Plan:
		To implement pawn promotion, implement the legal move generator as a number of piece-specific
			move generators
                      
*/

/* KNOWN BUGS/ISSUES
	v0.43:
		- The material advantage for pieces does not seem to be reset when you start a new game (hit 'r').
		- If you drag a piece off the board the game will crash.
		- Sometimes if you hit 's' to score the board position a move will be made and not undone.
		- There are a lot of bugs with generateFullLegalMoveList(). There are likely multiple problems here:
			(1) incorrect in-check testing and (2) errors in the undoMove() function.
*/


// includes
#ifdef OS_WINDOWS
	#include "stdafx.h"
	#include "opencv\cv.h"
	#include "opencv2\highgui\highgui.hpp"
#else
	#include <cv.h>
	#include <highgui.h>
#endif

// namespaces
using namespace cv;
using namespace std;


// structs and struct initializers
struct mouse_info_struct { int x,y; };
struct selectedSquare    { int x,y; };
struct selectedPiece     { int startX,startY,startLoc,currentX,currentY,grabbedPiece; }; 
struct moveStruct		 { int moveFrom,moveTo; };
moveStruct makeMoveStruct( int moveFrom, int moveTo )
{
	moveStruct tempStruct = {moveFrom, moveTo};
	return tempStruct;
}

// classes
class pieceClass
{
	// This class contains information about an individual piece.
	
	// Later, we will make a list of all pieces for each player.
	//  To keep track of which pieces are which pieces the following convention is to be used:      
    /*   entry[i] = 
                 0 - king          8 - a pawn
                 1 - queen         9 - b pawn
                 2 - a rook        10 - c pawn
                 3 - h rook        11 - d pawn
                 4 - c bishop      12 - e pawn
                 5 - f bishop      13 - f pawn 
                 6 - b knight      14 - g pawn
                 7 - g knight      15 - h pawn
                          
    */


public: 
	int identity;  // 1=pawn, 2=knight, 3=bishop, 4=rook, 5=queen, 6=king
    int value;     /* 100=pawn, 325=knight, 335=bishop, 540=rook, 1050=queen, 0=king */
    int location;  /* where the piece is on the board, given on a 120-byte board representation
                        a1 = 91, h1 = 98, a8 = 21 & h8 = 28, notice this leaves two rows above/below 
                        and one column to either side of the board. This will be useful for edge detection */
    int everMoved; /* has this piece ever moved before, 0=no, 1=yes */ 
	int owner;     // 1=white, -1=black
	int index;     // pieces are numbered 0 to 15 per side; this enables unique identification between identical pieces
       
    /*...*/              /* other things to be added later */

	pieceClass()
	{
		identity = 0;
		value = 0;
		location = 0;
		everMoved = 0;
		owner = 0;
		index = -1;
	};

	void initializePiece(int a, int b, int c, int d, int e, int f)
	{
		identity = a;
		value = b;
		location = c;
		everMoved = d;
		owner = e;
		index = f;
	}

};
class boardClass
{
	// This class allows us to create a board objects.

private:
	static const int initialBoard[120];

public:
	// The actual board with pieces on it
	int board[120];

	// Some useful values for easy functionality
	int epSq; // this variable should hold the location of any pawn available for capture under en passant
	int inCheck[2]; // 0 = no check, 1 = in check; inCheck[0] = white, inCheck[1] = black
	moveStruct lastMove; // stores the last move made, useful for undoing the last move
	pieceClass capturedPiece; // used to store any piece that was just captured; 
							  //	useful for quickly undoing the last move
	int pastEverMovedStatus; // used to store the ever move status of the last piece that moved;
							 //		this member is useful for reseting the everMoved status during an undoMove
	int canUndo; // whether or not we can undo; if we just undid one move we won't know what the next piece 
				 //		to uncapture is, so we can typically only undo one move using the information from 
				 //		the board class. if we want to undo further we'll have to replay the entire game 
				 //		from the png file.
	vector <moveStruct> legalMoves; // a list of all legal moves for the current position

	// For scoring the board position
	vector <int> moveScores; // holds the evaluation value for each possible move for the current board position
	int alpha; // alpha
	int beta;  // beta
	int material; // the material difference between the players; 
				  //	positive values mean white is ahead, negative mean black is ahead.

	// Initialize the board
	void initializeBoard(int board[120])
	{
		for (int i=0; i<120; i++)
		{
			board[i] = initialBoard[i];
		}
	}

	boardClass() 
	{ 
		initializeBoard(board); 
		material = 0;
		canUndo = 0;
	}
};
class squareTablesClass
{
private:
	static const int pawnTable   [120];
	static const int knightTable [120];
	static const int bishopTable [120];
	static const int kingTableMid[120];
	static const int kingTableEnd[120];

public:
	int pawnTableW   [120];
	int knightTableW [120];
	int bishopTableW [120];
	int kingTableMidW[120];
	int kingTableEndW[120];
	int pawnTableB   [120];
	int knightTableB [120];
	int bishopTableB [120];
	int kingTableMidB[120];
	int kingTableEndB[120];

	// Initialize the board
	void initializeTables(int pawnTableW[120], int knightTableW[120], int bishopTableW[120], int kingTableMidW[120], int kingTableEndW[120],
						  int pawnTableB[120], int knightTableB[120], int bishopTableB[120], int kingTableMidB[120], int kingTableEndB[120])
	{
		for (int i=0; i<120; i++)
		{
			pawnTableW[i] = pawnTable[i];
			pawnTableB[i] = pawnTable[119-i];

			knightTableW[i] = knightTable[i];
			knightTableB[i] = knightTable[119-i];

			bishopTableW[i] = bishopTable[i];
			bishopTableB[i] = bishopTable[119-i];

			kingTableMidW[i] = kingTableMid[i];
			kingTableMidB[i] = kingTableMid[119-i];

			kingTableEndW[i] = kingTableEnd[i];
			kingTableEndB[i] = kingTableEnd[119-i];
		}
	}

	squareTablesClass() { initializeTables(pawnTableW, knightTableW, bishopTableW, kingTableMidW, kingTableEndW,
										   pawnTableB, knightTableB, bishopTableB, kingTableMidB, kingTableEndB); }
};

// helper templates
template <typename T> int sgn(T val) { // used for returning the sign of a variable with unknown type
    return (T(0) < val) - (val < T(0));
}

// Function Table of Contents
void displayBoardText			(int board[120]);
void displayBoardSprites		(Mat boardSprites);
void displayBoard				(Mat boardImage, Mat boardSprites, Mat tempSprite, int board[120]);
void getPieceImage				(Mat boardSprites, Mat tempSprite, int pieceSelection);
int  getPieceID					(void);
void on_mouse					(int event, int x, int y, int flags, void* param);
void setMoveFrom				(void);
void setMoveTo					(void);
void makeMoveFromMouseclick		(void);
void initializePieceList		(pieceClass pieceList[16], int player);
int  generatePseudoLegalMoveList(int board[120], vector<moveStruct> &legalMoveList, pieceClass pieceList[16], int toMove);
int  generateFullLegalMoveList  (boardClass board, vector<moveStruct> &legalMoveList, pieceClass whitePieceList[16], pieceClass blackPieceList[16], int playersTurn);
void printLegalMoveList			(vector<moveStruct> legalMoveList);
void updatePieceInfo			(pieceClass pieceList[16]);
void printPieceInfo				(pieceClass pieceList[16]);
void printDebugInfo				(boardClass board, pieceClass whitePieceList[16], pieceClass blackPieceList[16]);
void makeRandomMove				(vector<moveStruct> legalMoveList);
int  randomNumber				(int min_value, int max_value);
int  inCheck					(int board[120], pieceClass whitePieceList[16], pieceClass blackPieceList[16], int playerToCheck);
void makeMove                   (moveStruct move, pieceClass whitePieceList[16], pieceClass blackPieceList[16], boardClass &board, int &playersTurn);
int  undoMove					(pieceClass whitePieceList[16], pieceClass blackPieceList[16], boardClass &board, int &playersTurn);
void displayMainMenu			(void);
int  lazyEval					(pieceClass whitePieceList[16], pieceClass blackPieceList[16], boardClass board);
void lazyEvalAllLegalMoves		(pieceClass whitePieceList[16], pieceClass blackPieceList[16], boardClass &board, int player);
void displayMoveScores			(boardClass board);
void updateBoardLegalMoveList	(vector<moveStruct> legalMoveList, boardClass &board);
int  checkMoveLegality			(moveStruct potentialMove, boardClass board, pieceClass whitePieceList[16], pieceClass blackPieceList[16], int player);

// global variables
boardClass board;
mouse_info_struct mousePressInfo  = {-1,-1};
mouse_info_struct currentMouseLoc = {-1,-1};
selectedSquare    moveFrom = {-1,-1};
selectedSquare    moveTo   = {-1,-1};
int mouseButtonDown        = 0;
int mouseWasJustPressed    = 0;
int mouseWasJustReleased   = 0;
selectedPiece pieceGrabbed = {-1,-1,-1,-1,-1,0}; // Piece ID for currently grabbed piece
pieceClass whitePieceList[16];
pieceClass blackPieceList[16];
squareTablesClass squareTables;
int playersTurn = 1; // 1=white, 0=black

// Move Offsets
//	The following offsets can be added to a piece's location to generate a potential move location
int pawnOffset[4]    = {9, 10, 11, 0};                        // For white these offsets should be made negative
int knightOffset[9]  = {-21, -19, -8, -12, 19, 21, 8, 12, 0}; // These include all 8 possible space offsets for the knight 
int bishopOffset[5]  = {-9, 9, -11, 11, 0};                   // Obviously there will be some repetition here to get a bishop moving more than one space 
int rookOffset[5]    = {-10, 10, -1, 1, 0};                   // Similar to the bishop, these need to be repeated to get rooks moving more than one space 
int queenOffset[9]   = {-9, 9, -11, 11, -10, 10, -1, 1, 0};   // Effectively Rook and Bishop combined 
int kingOffset[9]    = {-9, 9, -11, 11, -10, 10, -1, 1, 0};   // Same as the queen, but don't repeat 

const int boardClass::initialBoard[] = 
	{-99, -99, -99, -99, -99, -99, -99, -99, -99, -99,
	 -99, -99, -99, -99, -99, -99, -99, -99, -99, -99,
	 -99,  -4,  -2,  -3,  -5,  -6,  -3,  -2,  -4, -99,
	 -99,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1, -99,
	 -99,   0,   0,   0,   0,   0,   0,   0,   0, -99,
	 -99,   0,   0,   0,   0,   0,   0,   0,   0, -99,
	 -99,   0,   0,   0,   0,   0,   0,   0,   0, -99,
	 -99,   0,   0,   0,   0,   0,   0,   0,   0, -99,
	 -99,   1,   1,   1,   1,   1,   1,   1,   1, -99,
	 -99,   4,   2,   3,   5,   6,   3,   2,   4, -99,
	 -99, -99, -99, -99, -99, -99, -99, -99, -99, -99,
	 -99, -99, -99, -99, -99, -99, -99, -99, -99, -99 };

// Square Tables
const int squareTablesClass::pawnTable[120] = 
	{
		-1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
		-1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
		-1,  0,  0,  0,  0,  0,  0,  0,  0, -1,
		-1, 50, 50, 50, 50, 50, 50, 50, 50, -1,
		-1, 10, 10, 20, 30, 30, 20, 10, 10, -1,
		-1,  5,  5, 10, 27, 27, 10,  5,  5, -1,
		-1,  0,  0,  0, 25, 25,  0,  0,  0, -1,
		-1,  5, -5,-10,  0,  0,-10, -5,  5, -1,
		-1,  5, 10, 10,-25,-25, 10, 10,  5, -1,
		-1,  0,  0,  0,  0,  0,  0,  0,  0, -1,
		-1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
		-1, -1, -1, -1, -1, -1, -1, -1, -1, -1
	};

const int squareTablesClass::bishopTable[120] = 
	{
		-1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
		-1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
		-1,-20,-10,-10,-10,-10,-10,-10,-20, -1,
		-1,-10,  0,  0,  0,  0,  0,  0,-10, -1,
		-1,-10,  0,  5, 10, 10,  5,  0,-10, -1,
		-1,-10,  5,  5, 10, 10,  5,  5,-10, -1,
		-1,-10,  0, 10, 10, 10, 10,  0,-10, -1,
		-1,-10, 10, 10, 10, 10, 10, 10,-10, -1,
		-1,-10,  5,  0,  0,  0,  0,  5,-10, -1,
		-1,-20,-10,-40,-10,-10,-40,-10,-20, -1,
		-1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
		-1, -1, -1, -1, -1, -1, -1, -1, -1, -1
	};

const int squareTablesClass::knightTable[120] = 
	{
		-1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
		-1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
		-1,-50,-40,-30,-30,-30,-30,-40,-50, -1,
		-1,-40,-20,  0,  0,  0,  0,-20,-40, -1,
		-1,-30,  0, 10, 15, 15, 10,  0,-30, -1,
		-1,-30,  5, 15, 20, 20, 15,  5,-30, -1,
		-1,-30,  0, 15, 20, 20, 15,  0,-30, -1,
		-1,-30,  5, 10, 15, 15, 10,  5,-30, -1,
		-1,-40,-20,  0,  5,  5,  0,-20,-40, -1,
		-1,-50,-40,-20,-30,-30,-20,-40,-50, -1,
		-1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
		-1, -1, -1, -1, -1, -1, -1, -1, -1, -1
	};

const int squareTablesClass::kingTableMid[120] = 
	{
		-1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
		-1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
		-1,-30,-40,-40,-50,-50,-40,-40,-30, -1,
		-1,-30,-40,-40,-50,-50,-40,-40,-30, -1,
		-1,-30,-40,-40,-50,-50,-40,-40,-30, -1,
		-1,-30,-40,-40,-50,-50,-40,-40,-30, -1,
		-1,-20,-30,-30,-40,-40,-30,-30,-20, -1,
		-1,-10,-20,-20,-20,-20,-20,-20,-10, -1,
		-1, 20, 20,  0,  0,  0,  0, 20, 20, -1,
		-1, 20, 30, 10,  0,  0, 10, 30, 20, -1,
		-1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
		-1, -1, -1, -1, -1, -1, -1, -1, -1, -1
	}; 

const int squareTablesClass::kingTableEnd[120] =
	{
		-1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
		-1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
		-1,-50,-40,-30,-20,-20,-30,-40,-50, -1,
		-1,-30,-20,-10,  0,  0,-10,-20,-30, -1,
		-1,-30,-10, 20, 30, 30, 20,-10,-30, -1,
		-1,-30,-10, 30, 40, 40, 30,-10,-30, -1,
		-1,-30,-10, 30, 40, 40, 30,-10,-30, -1,
		-1,-30,-10, 20, 30, 30, 20,-10,-30, -1,
		-1,-30,-30,  0,  0,  0,  0,-30,-30, -1,
		-1,-50,-30,-30,-30,-30,-30,-30,-50, -1,
		-1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
		-1, -1, -1, -1, -1, -1, -1, -1, -1, -1
	};



int main(int argc, char* argv[])
{
	// Initialize the board image and sprites
	Mat boardSprites = imread("./Images/Chess Sprites 1 Edited.png", CV_LOAD_IMAGE_COLOR);
	Mat boardImage(400,400,CV_8UC3);
	Mat tempSprites(50,50,CV_8UC3);

	// Initialize a variable to get the desired move
	char move[2];

	// Initialize a legal move list
	vector<moveStruct> legalMoveList;

	// Initialize a piece list for each player
	initializePieceList(whitePieceList, 1);
	initializePieceList(blackPieceList, 2);

	// Initialize game board window
	//namedWindow("Sprites",1);
	namedWindow("Kingsmen Chess v0.32",0);

	// Initialize mouse callback
	setMouseCallback("Kingsmen Chess v0.32", on_mouse, 0);

	// Display main menu
	displayMainMenu();

	while (true)
	{
		// Display the board (and anything as desired)
		//displayBoardText(board.board);
		//displayBoardSprites(boardSprites);
		displayBoard(boardImage, boardSprites, tempSprites, board.board);

		// Handle key presses and drag-drop events; If set to 0 drag drop will not function
		char c = cvWaitKey(5);
		if (c==27) // Hit escape to exit
			break;
		else if (c=='r') // restart the game
		{	
			initializePieceList(whitePieceList, 1);
			initializePieceList(blackPieceList, 2);
			board.initializeBoard(board.board);
			playersTurn = 1;
			displayMainMenu();
		}
		else if (c=='l') // print legal moves
		{
			if (playersTurn)
				generateFullLegalMoveList(board, legalMoveList, whitePieceList, blackPieceList, 1);
			else
				generateFullLegalMoveList(board, legalMoveList, whitePieceList, blackPieceList, -1);

			if (playersTurn)
			{
				// Compute legal moves for white
				//generatePseudoLegalMoveList(board.board, legalMoveList, whitePieceList, 1);
				printf("\n\nLEGAL MOVE INFO FOR WHITE\n");
				printLegalMoveList(legalMoveList);
			}

			else
			{
				// Compute legal moves for black
				//generatePseudoLegalMoveList(board.board, legalMoveList, blackPieceList, -1);
				printf("\n\nLEGAL MOVE INFO FOR BLACK\n");
				printLegalMoveList(legalMoveList);
			}
		}
		else if (c=='a') // have the computer ai make a move for white
		{
			if (playersTurn)
			{
				printf("\n\nAI MOVE (WHITE)");
				generateFullLegalMoveList(board, legalMoveList, whitePieceList, blackPieceList, 1);
			}
			else
			{
				printf("\n\nAI MOVE (BLACK)");
				generateFullLegalMoveList(board, legalMoveList, whitePieceList, blackPieceList, -1);
			}

			makeRandomMove(legalMoveList);
		}
		else if (c=='d') // print debugging info
		{
			printDebugInfo(board, whitePieceList, blackPieceList);
		}
		else if (c=='c') // check if one of the players is in check
		{
			board.inCheck[0] = inCheck(board.board, whitePieceList, blackPieceList, 1);
			board.inCheck[1] = inCheck(board.board, whitePieceList, blackPieceList, 0);

			printf("\n\nIN-CHECK STATUS\n");
			if (board.inCheck[0])
				printf("\n\tWhite player is in check!\n");
			else
				printf("\n\tWhite player is not in check.\n");

			if (board.inCheck[1])
				printf("\n\tBlack player is in check!\n");
			else
				printf("\n\tBlack player is not in check.\n");
		}
		else if (c=='s') // score the current board position
		{
			printf("\n\nBOARD EVAL");
			printf("\n\tLazy Eval Score: %d", lazyEval(whitePieceList, blackPieceList, board));

			if (playersTurn)
			{
				printf("\n\n\tWhite's Potential Move Lazy Eval's Scores:");
				lazyEvalAllLegalMoves(whitePieceList, blackPieceList, board, 1);
				displayMoveScores(board);
			}
			else
			{
				printf("\n\n\tBlack's Potential Move Lazy Eval's Scores:");
				lazyEvalAllLegalMoves(whitePieceList, blackPieceList, board, -1);
				displayMoveScores(board);
			}
		}
		else if (c=='u') // undo move
		{
			printf("\n\nUNDO MOVE");
			if (board.canUndo)
			{
				printf("\n\tUndoing move %d -> %d", board.lastMove.moveFrom, board.lastMove.moveTo);
				undoMove(whitePieceList, blackPieceList, board, playersTurn);
			}
			else
				printf("\n\tUnable to undo move.");
		}
	}

	return 0;
}

void displayBoardText(int board[120])
{
     int i, j;
     
	 //for (i=0; i<40; i++)
	 //    printf("\n\n");
     
     int row = 8, column = 1;
     
     printf("                                 ___________________\n");
     for (i=2; i<=9; i++){
         printf("                               %d | ", row);
         row--;         
     for (j=1; j<=8; j++){
         if (board[10*i + j] == 0)
            printf("%c%c", '-', ' ');
         
         if (board[10*i + j] == 1)
            printf("%c%c", 'P', ' ');
         if (board[10*i + j] == 2)
            printf("%c%c", 'N', ' ');
         if (board[10*i + j] == 3)
            printf("%c%c", 'B', ' ');
         if (board[10*i + j] == 4)
            printf("%c%c", 'R', ' ');
         if (board[10*i + j] == 5)
            printf("%c%c", 'Q', ' ');
         if (board[10*i + j] == 6)
            printf("%c%c", 'K', ' ');
            
         if (board[10*i + j] == -1)
            printf("%c%c", 'p', ' ');
         if (board[10*i + j] == -2)
            printf("%c%c", 'n', ' ');
         if (board[10*i + j] == -3)
            printf("%c%c", 'b', ' ');
         if (board[10*i + j] == -4)
            printf("%c%c", 'r', ' ');
         if (board[10*i + j] == -5)
            printf("%c%c", 'q', ' ');
         if (board[10*i + j] == -6)
            printf("%c%c", 'k', ' ');
     }
         printf("|\n");
     
     }   
     printf("                                 -------------------\n");
     printf("                                   a b c d e f g h\n");
}

void displayBoardSprites(Mat boardSprites)
{
	imshow("Sprites", boardSprites);
}

void displayBoard(Mat boardImage, Mat boardSprites, Mat tempSprite, int board[120])
{
	int i, j; 
	int r, s;
	Vec3b pixel;
	Rect roi, pixelRoi;

	// Layer 1: Board Tiles
	roi.width = 50;
	roi.height = 50;
	int colorSelection = 7;
	for (i=0; i<8; i++){
		for (j=0; j<8; j++){
			getPieceImage(boardSprites, tempSprite, colorSelection);
			roi.y = i*50;
			roi.x = j*50;
			tempSprite.copyTo(boardImage(roi));
			
			if (colorSelection == 7)
				colorSelection = 8;
			else
				colorSelection = 7;
			
		}

		if (colorSelection == 7)
				colorSelection = 8;
			else
				colorSelection = 7;
	}

	// Layer 2: Piece Tiles
	int piecePresent = 0; // Whether or not we found a piece to draw
	roi.width = 1;
	roi.height = 1;
	pixelRoi.width = 1;
	pixelRoi.height = 1;
	for (i=2; i<=9; i++){
    for (j=1; j<=8; j++){
		piecePresent = 0;

		// Select the right sprite if we see a piece
        if (board[10*i + j] == 1){
           getPieceImage(boardSprites, tempSprite, 1);
		   piecePresent = 1;
		}
        if (board[10*i + j] == 2){
           getPieceImage(boardSprites, tempSprite, 2);
		   piecePresent = 1;
		}
        if (board[10*i + j] == 3){
           getPieceImage(boardSprites, tempSprite, 3);
		   piecePresent = 1;
		}
        if (board[10*i + j] == 4){
           getPieceImage(boardSprites, tempSprite, 4);
		   piecePresent = 1;
		}
        if (board[10*i + j] == 5){
           getPieceImage(boardSprites, tempSprite, 5);
		   piecePresent = 1;
		}
        if (board[10*i + j] == 6){
           getPieceImage(boardSprites, tempSprite, 6);
		   piecePresent = 1;
		}
           
        if (board[10*i + j] == -1){
           getPieceImage(boardSprites, tempSprite, -1);
		   piecePresent = 1;
		}
        if (board[10*i + j] == -2){
           getPieceImage(boardSprites, tempSprite, -2);
		   piecePresent = 1;
		}
        if (board[10*i + j] == -3){
           getPieceImage(boardSprites, tempSprite, -3);
		   piecePresent = 1;
		}
        if (board[10*i + j] == -4){
           getPieceImage(boardSprites, tempSprite, -4);
		   piecePresent = 1;
		}
        if (board[10*i + j] == -5){
           getPieceImage(boardSprites, tempSprite, -5);
		   piecePresent = 1;
		}
        if (board[10*i + j] == -6){
           getPieceImage(boardSprites, tempSprite, -6);
		   piecePresent = 1;
		}
    
		if (piecePresent){
			int startY = (i-2)*50;
			int startX = (j-1)*50;
			int curX, curY; 

			for (r=0; r<50; r++){
				for (s=0; s<50; s++){
					roi.y = startY+s;
					roi.x = startX+r;
					pixelRoi.x = r;
					pixelRoi.y = s;

					pixel = tempSprite.at<Vec3b>(s, r);

					if (pixel[0]!=14 || pixel[1]!=201 || pixel[2]!=255)
						tempSprite(pixelRoi).copyTo(boardImage(roi));
				}
			}
		}

	}
	}

	// Layer 3: Selected piece
	//	If desired, an extra layer can be added here for moving a piece around freely.
	roi.width = 1;
	roi.height = 1;
	pixelRoi.width = 1;
	pixelRoi.height = 1;
	if (pieceGrabbed.grabbedPiece != 0)
	{
		getPieceImage(boardSprites, tempSprite, pieceGrabbed.grabbedPiece);
		int startY = pieceGrabbed.currentY - pieceGrabbed.startY % 50;
		int startX = pieceGrabbed.currentX - pieceGrabbed.startX % 50;
		int curX, curY; 

		for (r=0; r<50; r++){
			for (s=0; s<50; s++){
				
				if (r+startX<400 && 
					s+startY<400 &&
					r+startX>=0 && 
					s+startY>=0)
				{
					roi.y = startY+s;
					roi.x = startX+r;
					pixelRoi.x = r;
					pixelRoi.y = s;

					pixel = tempSprite.at<Vec3b>(s, r);

					if (pixel[0]!=14 || pixel[1]!=201 || pixel[2]!=255)
						tempSprite(pixelRoi).copyTo(boardImage(roi));
				}
			}
		}
	}

	imshow("Kingsmen Chess v0.32", boardImage);
}

void displayMainMenu()
{
	printf("\n\n");
	printf("****************************\n");
	printf("*** KINGSMEN CHESS v0.43 ***\n");
	printf("****************************\n");
	printf("\n");
	printf("\t'r'   - restart game\n");
	printf("\t'd'   - print debug info\n");
	printf("\t'l'   - print legal move list\n");
	printf("\t'c'   - print the in-check status of each player\n");
	printf("\t'a'   - have ai make the next move\n");
	printf("\t's'   - score the current board position\n");
	printf("\t'u'   - undo last move\n");
	printf("\t'esc' - exit program\n");
	printf("\n\n");
}

void getPieceImage(Mat boardSprites, Mat tempSprite, int pieceSelection)
{
	Rect roi;
	roi.width  = 50;
	roi.height = 50;

	if (pieceSelection == 0) // Empty (white) square
	{
		roi.x = 0;
		roi.y = 500;
	}

	if (pieceSelection == 7) // Light square
	{
		roi.x = 50;
		roi.y = 500;
	}

	if (pieceSelection == 8) // Dark square
	{
		roi.x = 100;
		roi.y = 500;
	}

	if (pieceSelection == 1) // White pawn
	{
		roi.x = 0;
		roi.y = 0;
	}

	if (pieceSelection == 2) // White knight
	{
		roi.x = 100;
		roi.y = 0;
	}

	if (pieceSelection == 3) // White bishop
	{
		roi.x = 50;
		roi.y = 0;
	}

	if (pieceSelection == 4) // White rook
	{
		roi.x = 150;
		roi.y = 0;
	}

	if (pieceSelection == 5) // White queen
	{
		roi.x = 200;
		roi.y = 0;
	}

	if (pieceSelection == 6) // White king
	{
		roi.x = 250;
		roi.y = 0;
	}

	if (pieceSelection == -1) // Black pawn
	{
		roi.x = 0;
		roi.y = 50;
	}

	if (pieceSelection == -2) // Black knight
	{
		roi.x = 100;
		roi.y = 50;
	}

	if (pieceSelection == -3) // Black bishop
	{
		roi.x = 50;
		roi.y = 50;
	}

	if (pieceSelection == -4) // Black rook
	{
		roi.x = 150;
		roi.y = 50;
	}

	if (pieceSelection == -5) // Black queen
	{
		roi.x = 200;
		roi.y = 50;
	}

	if (pieceSelection == -6) // Black king
	{
		roi.x = 250;
		roi.y = 50;
	}

	boardSprites(roi).copyTo(tempSprite);
}

int getPieceID()
{
	int selectedPiece = board.board[10*(moveFrom.y+2) + (moveFrom.x+1)];
	return selectedPiece;
}

void on_mouse(int event, int x, int y, int flags, void* param) {
	currentMouseLoc.x = x;
	currentMouseLoc.y = y;

	pieceGrabbed.currentX = x;
	pieceGrabbed.currentY = y;
	
	if (event == CV_EVENT_LBUTTONUP) 
	{
		if (mouseButtonDown)
			mouseWasJustReleased = 1;
		else
			mouseWasJustReleased = 0;

		mouseButtonDown = 0;
		
		if (mouseWasJustReleased)
		{
			mousePressInfo.x = x;
			mousePressInfo.y = y;

			currentMouseLoc.x = -1;
			currentMouseLoc.y = -1;

			setMoveTo();

			makeMoveFromMouseclick();

			pieceGrabbed.currentX = -1;
			pieceGrabbed.currentY = -1;
			pieceGrabbed.grabbedPiece = 0;


			//cout << "Mouse just released:  " << x << "," << y << " (" << moveTo.x << "," << moveTo.y << ")" << endl;
		}

	}

	if (event == CV_EVENT_LBUTTONDOWN)
	{
		if (mouseButtonDown==0)
			mouseWasJustPressed = 1;
		else
			mouseWasJustPressed = 0;

		mouseButtonDown = 1;
		
		if (mouseWasJustPressed)
		{
			mousePressInfo.x = x;
			mousePressInfo.y = y;
			setMoveFrom();

			pieceGrabbed.grabbedPiece = getPieceID();
			pieceGrabbed.startX = x;
			pieceGrabbed.startY = y;
			pieceGrabbed.startLoc = (10*(y/50 + 2) + (x/50 + 1));

			board.board[10*(moveFrom.y+2) + (moveFrom.x+1)] = 0;

			//cout << "Mouse just clicked:  " << x <<","<< y << " (" << moveFrom.x << "," << moveFrom.y << ")" <<endl;
		}
	}
}

void setMoveFrom()
{
	moveFrom.x = mousePressInfo.x / 50;
	moveFrom.y = mousePressInfo.y / 50;
}

void setMoveTo()
{
	moveTo.x = mousePressInfo.x / 50;
	moveTo.y = mousePressInfo.y / 50;
}

void makeMoveFromMouseclick()
{
	// Move the grabbed piece
	//	Note: we've already put the selected piece's original square to 0, so we don't have to do that here
	int from = 10*(moveFrom.y+2) + (moveFrom.x+1);
	int to   = 10*(moveTo.y+2)   + (moveTo.x+1);

	moveStruct potentialMove = {from, to};
	vector<moveStruct> legalMoveList;
	
	board.board[from] = pieceGrabbed.grabbedPiece; // Put the piece back for makeMove()'s sake

	// Find whether the moved piece was white or black
	/*
	int player = 0;
	for (int i=0; i<16; i++)
	{
		if (from == whitePieceList[i].location)
			player = 1;
		
		if (from == blackPieceList[i].location)
			player = -1;
	}
	*/

	// Check whether or not the move is legal
	int moveLegal = checkMoveLegality(potentialMove, board, whitePieceList, blackPieceList, playersTurn);

	// If legal, make the desired move
	if (moveLegal)
	{
		moveStruct move = {from,to};
		makeMove(move, whitePieceList, blackPieceList, board, playersTurn);
	}

	// If illegal move, don't allow it to happen
	else 
	{
		//board.board[from] = pieceGrabbed.grabbedPiece;

		for (int i=0; i<16; i++)
		{
			// Place the piece back where it started
			if ( 10*(moveFrom.y+2)+(moveFrom.x+1) == whitePieceList[i].location )
				whitePieceList[i].location = from;
			if ( 10*(moveFrom.y+2)+(moveFrom.x+1) == blackPieceList[i].location )
				blackPieceList[i].location = from;
		}
	}
}

void initializePieceList(pieceClass pieceList[16], int player)
{
	// This function will initialize a list of pieces for one of the players (player==1 is white, 
	//	player==2 is black).
	//
	// Recall:
	// entry[i] = 
    //             0 - king          8 - a pawn
    //             1 - queen         9 - b pawn
    //             2 - a rook        10 - c pawn
    //             3 - h rook        11 - d pawn
    //             4 - c bishop      12 - e pawn
    //             5 - f bishop      13 - f pawn 
    //             6 - b knight      14 - g pawn
    //             7 - g knight      15 - h pawn

	moveTo.x = -1;
	moveTo.y = -1;
	moveFrom.x = -1;
	moveFrom.y = -1;

	if (player==1) // White pieces
	{
		pieceList[0].initializePiece(6, 0,    95, 0, 1, 0); // king
		pieceList[1].initializePiece(5, 1050, 94, 0, 1, 1); // queen
		pieceList[2].initializePiece(4, 540,  91, 0, 1, 2); // a rook
		pieceList[3].initializePiece(4, 540,  98, 0, 1, 3); // h rook
		pieceList[4].initializePiece(3, 335,  93, 0, 1, 4); // c bishop
		pieceList[5].initializePiece(3, 335,  96, 0, 1, 5); // f bishop
		pieceList[6].initializePiece(2, 325,  92, 0, 1, 6); // b knight
		pieceList[7].initializePiece(2, 325,  97, 0, 1, 7); // g knight
		pieceList[8].initializePiece(1, 100,  81, 0, 1, 8); // pawn
		pieceList[9].initializePiece(1, 100,  82, 0, 1, 9); // pawn
		pieceList[10].initializePiece(1, 100,  83, 0, 1, 10); // pawn
		pieceList[11].initializePiece(1, 100,  84, 0, 1, 11); // pawn
		pieceList[12].initializePiece(1, 100,  85, 0, 1, 12); // pawn
		pieceList[13].initializePiece(1, 100,  86, 0, 1, 13); // pawn
		pieceList[14].initializePiece(1, 100,  87, 0, 1, 14); // pawn
		pieceList[15].initializePiece(1, 100,  88, 0, 1, 15); // pawn
	}

	else if (player==2) // Black pieces
	{
		pieceList[0].initializePiece(6, 0,    25, 0, -1, 0); // king
		pieceList[1].initializePiece(5, 1050, 24, 0, -1, 1); // queen
		pieceList[2].initializePiece(4, 540,  21, 0, -1, 2); // a rook
		pieceList[3].initializePiece(4, 540,  28, 0, -1, 3); // h rook
		pieceList[4].initializePiece(3, 335,  23, 0, -1, 4); // c bishop
		pieceList[5].initializePiece(3, 335,  26, 0, -1, 5); // f bishop
		pieceList[6].initializePiece(2, 325,  22, 0, -1, 6); // b knight
		pieceList[7].initializePiece(2, 325,  27, 0, -1, 7); // g knight
		pieceList[8].initializePiece(1, 100,  31, 0, -1, 8); // pawn
		pieceList[9].initializePiece(1, 100,  32, 0, -1, 9); // pawn
		pieceList[10].initializePiece(1, 100, 33, 0, -1, 10); // pawn
		pieceList[11].initializePiece(1, 100, 34, 0, -1, 11); // pawn
		pieceList[12].initializePiece(1, 100, 35, 0, -1, 12); // pawn
		pieceList[13].initializePiece(1, 100, 36, 0, -1, 13); // pawn
		pieceList[14].initializePiece(1, 100, 37, 0, -1, 14); // pawn
		pieceList[15].initializePiece(1, 100, 38, 0, -1, 15); // pawn
	}

	/*
	int i;

	// Initialize each piece's identity
	pieceList[0].identity = 6; // king
	pieceList[1].identity = 5; // queen
	pieceList[2].identity = 4; // a rook
	pieceList[3].identity = 4; // h rook
	pieceList[4].identity = 3; // c bishop
	pieceList[5].identity = 3; // f bishop
	pieceList[6].identity = 2; // b knight
	pieceList[7].identity = 2; // g knight
	for (i=8; i<16; i++) {pieceList[i].identity = 1;} // pawns
	
	// Initialize each piece's value
	pieceList[0].value = 0;		// king
	pieceList[1].value = 1050;  // queen
	pieceList[2].value = 540;   // a rook
	pieceList[3].value = 540;   // h rook
	pieceList[4].value = 335;   // c bishop
	pieceList[5].value = 335;   // f bishop
	pieceList[6].value = 325;   // b knight
	pieceList[7].value = 325;   // g knight
	for (i=8; i<16; i++){pieceList[i].value = 100;} // pawns

	// Initialize each piece's location
	if (player==1) // white
	{
		pieceList[0].location = 95; // king
		pieceList[1].location = 94; // queen
		pieceList[2].location = 91; // a rook
		pieceList[3].location = 98; // h rook
		pieceList[4].location = 93; // c bishop
		pieceList[5].location = 96; // f bishop
		pieceList[6].location = 92; // b knight
		pieceList[7].location = 97; // g knight
		for (i=8; i<16; i++) {pieceList[i].location = 73+i;}; // pawn
	}
	else if (player==2) // black
	{
		pieceList[0].location = 25; // king
		pieceList[1].location = 24; // queen
		pieceList[2].location = 21; // a rook
		pieceList[3].location = 28; // h rook
		pieceList[4].location = 23; // c bishop
		pieceList[5].location = 26; // f bishop
		pieceList[6].location = 22; // b knight
		pieceList[7].location = 27; // g knight
		for (i=8; i<16; i++) {pieceList[i].location = 23+i;}; // pawn
	}

	// Initialize each piece's 'everMoved' status
	for (i=0; i<16; i++){
		pieceList[i].everMoved = 0;
	}
	*/
}

int generatePseudoLegalMoveList(
	int                board[120], 
	vector<moveStruct> &legalMoveList, 
	pieceClass         pieceList[16],
	int                player)
{
	// This function generates a vector of all the legal moves for the player to move (1=white,
	//	-1=black). The returned value is the number of legal moves found.

	// Initialize some useful values
	int i,j;
	int numLegalMoves = 0;
	int potentialMoveTo;
	int pathClear, multiple;

	// Clear our the current legal move list
	legalMoveList.clear();

	/* Let's loop through our 16 pieces and come up with a legal move set, shall we */
    for (i=0; i<16; i++){

		if (pieceList[i].location == 0); // If the piece has been captured it can't possibly 
										  //	give us any legal moves

		else if (pieceList[i].identity == 1) // pawn
		{
			// Check to see if a piece is directly in front of the pawn.
			//	If not, it is listed in the legal moves list.
			potentialMoveTo = pieceList[i].location - 10*player;
			if (board[potentialMoveTo] == 0)
			{
				legalMoveList.push_back(makeMoveStruct(pieceList[i].location, potentialMoveTo));
				numLegalMoves++;

				// Now let's see if that pawn can also move two spaces ahead.
				if (pieceList[i].everMoved == 0) // If the pawn has never moved before,
				{
					potentialMoveTo = pieceList[i].location - 20*player;
					if (board[potentialMoveTo] == 0) // and if there is no piece at the target square
					{
						legalMoveList.push_back( makeMoveStruct(pieceList[i].location, potentialMoveTo));
						numLegalMoves++;
					}
				}
			}

			// Next we see if there is an opposing piece diagonally in front of the pawn.
			//	If there is, we add it that move to the legal moves list.
			potentialMoveTo = pieceList[i].location - 9*player;
			if (board[potentialMoveTo] != -99){ // If we're not moving off the board
				if (sgn(board[potentialMoveTo]) == -sgn(player)){ // and if we're capturing our opponent's piece
					legalMoveList.push_back(makeMoveStruct(pieceList[i].location, potentialMoveTo));
					numLegalMoves++;
				}
			}

			potentialMoveTo = pieceList[i].location - 11*player;
			if (board[potentialMoveTo] != -99){ // If we're not moving off the board
				if (sgn(board[potentialMoveTo]) == -sgn(player)){ // and if we're capturing an opponent's piece
					legalMoveList.push_back (makeMoveStruct(pieceList[i].location, potentialMoveTo));
					numLegalMoves++;
				}
			}

			// Finally, we need to add en passant checking
			/*
			...
			*/
		}

		else if (pieceList[i].identity == 2) // knight
		{
			for (j=0; knightOffset[j] != 0; j++)
			{
				potentialMoveTo = pieceList[i].location + knightOffset[j];
				if (board[potentialMoveTo] != -99){ // If the move is not off the board,
					if (sgn(board[potentialMoveTo]) != sgn(player)){ // and if we're not capturing our own piece
						legalMoveList.push_back (makeMoveStruct(pieceList[i].location, potentialMoveTo));
						numLegalMoves++;
					}
				}
			}  
		}

		else if (pieceList[i].identity == 3) // bishop
		{
			for (j=0; bishopOffset[j] != 0; j++)
			{
				pathClear = 1;
				for (multiple=1; pathClear; multiple++) // Loop through all the different directions, as stored in the offset
				{
					pathClear = 0; // Start with the assumption that there are no further moves until proven wrong
					potentialMoveTo = pieceList[i].location + bishopOffset[j]*multiple;
					if (board[potentialMoveTo] != -99){ // If the move isn't off the board,
						if ( sgn(board[potentialMoveTo]) != sgn(player)){ // and we aren't capturing our own piece
							legalMoveList.push_back (makeMoveStruct(pieceList[i].location, potentialMoveTo));
							numLegalMoves++;
						}

						if (board[potentialMoveTo] == 0) // If we're moving to an empty square the bishop can potentially move forward even more
							pathClear = 1;
					}
				}
			}
		}

		else if (pieceList[i].identity == 4) // rook
		{
			for (j=0; rookOffset[j] != 0; j++)
			{
				pathClear = 1;
				for (multiple=1; pathClear; multiple++)
				{
					pathClear = 0;
					potentialMoveTo = pieceList[i].location + rookOffset[j]*multiple;
					if (board[potentialMoveTo] != -99){ // If the move isn't off the board,
						if (sgn(board[potentialMoveTo]) != sgn(player)){ // and we aren't capturing our own piece
							legalMoveList.push_back (makeMoveStruct(pieceList[i].location, potentialMoveTo));
							numLegalMoves++;
						}

						if (board[potentialMoveTo] == 0) // If we're moving to an empty square the rook can potentially move forward further
							pathClear = 1;

					}
				}
			}
		}

		else if (pieceList[i].identity == 5) // queen
		{
			for (j=0; queenOffset[j] != 0; j++)
			{
				pathClear = 1;
				for (multiple=1; pathClear; multiple++)
				{
					pathClear = 0;
					potentialMoveTo = pieceList[i].location + queenOffset[j]*multiple;
					if (board[potentialMoveTo] != -99){ // If the move isn't off the board
						if (sgn(board[potentialMoveTo]) != sgn(player)){ // and we aren't capturing our own piece
							legalMoveList.push_back(makeMoveStruct(pieceList[i].location, potentialMoveTo));
							numLegalMoves++;
						}

						if (board[potentialMoveTo] == 0) // If we're moving to an empty square the queen can potentially move forward further
							pathClear = 1;
					}
				}
			}
		}

		else if (pieceList[i].identity == 6) // king
		{
			for (j=0; kingOffset[j] !=- 0; j++)
			{
				potentialMoveTo = pieceList[i].location + kingOffset[j];
				if (board[potentialMoveTo] != -99){ // If the move isn't off the board
					if (sgn(board[potentialMoveTo]) != sgn(player)){ // and we aren't capturing our own piece
						legalMoveList.push_back(makeMoveStruct(pieceList[i].location, potentialMoveTo));
						numLegalMoves++;
					}
				}
			}

			// Need to add castling check here
			//  Note: we still need to make sure we're not moving through check
			if (pieceList[i].everMoved == 0){ // if the king has never moved
				// Check castling with the a-file rook
				potentialMoveTo = pieceList[i].location - 2;
				if (pieceList[2].everMoved==0 && pieceList[2].location==pieceList[i].location-4){ // if the a-file rook has never moved and still exists
					if (board[pieceList[i].location-1]==0 && board[pieceList[i].location-2]==0 && board[pieceList[i].location-3]==0){ // and if all the squares b/w 
																															 //  the king and rook are empty
						legalMoveList.push_back(makeMoveStruct(pieceList[i].location, potentialMoveTo));
						numLegalMoves++;
					}
				}

				// Check castling with the h-file rook
				potentialMoveTo = pieceList[i].location + 2;
				if (pieceList[3].everMoved==0 && pieceList[3].location==pieceList[i].location+3){ // if the h-file rook has never moved and still exists
					if (board[pieceList[i].location+1]==0 && board[pieceList[i].location+2]==0){ // and if all the spaces b/w the king and rook are empty
						legalMoveList.push_back(makeMoveStruct(pieceList[i].location, potentialMoveTo));
						numLegalMoves++;
					}
				}
			}
		}


	}
	return numLegalMoves;
}


int generateFullLegalMoveList(
	boardClass         board, 
	vector<moveStruct> &legalMoveList, 
	pieceClass         whitePieceList[16],
	pieceClass		   blackPieceList[16],
	int                player)
{
	// This function is similar to generatePseudoLegalMoveList() except that it additionally
	//	checks for moves that result in check for the moving side.
	//
	// player=1 (white), player=-1 (black)

	// Find the Pseudo legal moves
	int numLegalMoves;
	if (player==1)
		numLegalMoves = generatePseudoLegalMoveList(board.board, legalMoveList, whitePieceList, player);
	else
		numLegalMoves = generatePseudoLegalMoveList(board.board, legalMoveList, blackPieceList, player);

	// Switch over to black=0 scheme:
	int playersTurn = player;
	if (playersTurn==-1)
		playersTurn = 0;

	// Make sure none of the moves end in check for the moving player
	int check;
	for (int i=0; i<numLegalMoves; i++)
	{
		makeMove(legalMoveList[i], whitePieceList, blackPieceList, board, playersTurn);
		check = inCheck(board.board, whitePieceList, blackPieceList, !playersTurn); // note: makeMove() switched who's turn it actually is
		
		if (check){
			printf("\nIn generateFullLegalMoveList(). Check-producing move found! Following move has been deemed illegal:");
			printf("\n\tMove: %d->%d", legalMoveList[i].moveFrom, legalMoveList[i].moveTo);
		
		}
		undoMove(whitePieceList, blackPieceList, board, playersTurn);

		if (check){ // This move resulted in check and should be taken off the legal move list
			legalMoveList.erase(legalMoveList.begin()+i);
			numLegalMoves--;
			i--;
		}

	}


	numLegalMoves = legalMoveList.size();
	return numLegalMoves;
}

void printLegalMoveList(vector<moveStruct> legalMoveList)
{
	int numLegalMoves = legalMoveList.size();
	
	int row, col;
	char rowFrom,colFrom, rowTo,colTo;
	char colVals[] = "abcdefgh";
	char rowVals[] = "87654321";

	printf("\n\tNumber of legal moves found: %d\n", numLegalMoves);
	for (int i=0; i<numLegalMoves; i++)
	{
		row = legalMoveList[i].moveFrom / 10;
		col = legalMoveList[i].moveFrom % 10;
		rowFrom = rowVals[row-2];
		colFrom = colVals[col-1];

		row = legalMoveList[i].moveTo / 10;
		col = legalMoveList[i].moveTo % 10;
		rowTo = rowVals[row-2];
		colTo = colVals[col-1];

		printf("\t%d -> %d (%c%c -> %c%c)\n",legalMoveList[i].moveFrom,legalMoveList[i].moveTo, colFrom,rowFrom, colTo,rowTo);
	}
}

void printPieceInfo(pieceClass pieceList[16])
{
	// This function can be used to print the all the piece info for a particular player.
	//	Hopefully this function will be useful during debugging.

	int i;

	printf("\tIndex - ID - Location - Value - Ever Moved\n");
	for (i=0; i<16; i++)
	{
		printf("\t%5.1d - %2.1d - %8.1d - %5.1d - %10.1d\n", 
			i,
			pieceList[i].identity,
			pieceList[i].location,
			pieceList[i].value,
			pieceList[i].everMoved);
	}
}

void printDebugInfo(boardClass board, pieceClass whitePieceList[16], pieceClass blackPieceList[16])
{
	printf("\n\nDEBUG INFO\n");
	displayBoardText(board.board);
	printf("\n\tWhite piece info\n");
	printPieceInfo(whitePieceList);
	printf("\n\tBlack piece info\n");
	printPieceInfo(blackPieceList);
}

void makeRandomMove(vector<moveStruct> legalMoveList)
{
	// This function just takes a random move off the legalMoveList and implements it.
	
	int numLegalMoves = legalMoveList.size();
	printf("\n\tNumber of legal moves: %d", numLegalMoves);
	moveStruct chosenMove = legalMoveList[randomNumber(0,numLegalMoves-1)];
	printf("\n\tChosen AI move: %d -> %d", chosenMove.moveFrom, chosenMove.moveTo);

	makeMove(chosenMove, whitePieceList, blackPieceList, board, playersTurn);

}

int randomNumber(int min_value, int max_value)
{
    int number;
    
    /* initialize random generator */
    srand ( time(NULL) );

    /* generate random numbers */

    /*Syntax*/
    /*
    To get a number between MINIMUM and MAXIMUM, use:
    rand() % (MAXIMUM - MINUMIM + 1) + MINIMUM;
    */
  
    number = rand() % (max_value - min_value + 1) + min_value;
    
    return number;
}

int inCheck(int board[120], pieceClass whitePieceList[16], pieceClass blackPieceList[16], int playerToCheck)
{
	// This function checks whether or not the current board position. The returned int is 0 for not in check
	//	and 1 for in check.
	// Note: playerToCheck (1=white, 0=black) is the owner of the king to check whether or not it is in check.

	int i, check = 0;
	vector<moveStruct> legalMoveList;

	if (playerToCheck){ // white
		int numLegalMoves = generatePseudoLegalMoveList(board, legalMoveList, blackPieceList, -1);
		for (i=0; i<numLegalMoves-1; i++){
			if (whitePieceList[0].location == legalMoveList[i].moveTo)
				check = 1;
		}
	}
	else { // black
		int numLegalMoves = generatePseudoLegalMoveList(board, legalMoveList, whitePieceList, 1);
		for (i=0; i<numLegalMoves-1; i++){
			if (blackPieceList[0].location == legalMoveList[i].moveTo)
				check = 1;
		}
	}

	return check;
}

void makeMove(moveStruct move, pieceClass whitePieceList[16], pieceClass blackPieceList[16], boardClass &board, int &playersTurn)
{
	// This function serves to take a move and implement it, including updating the two piece lists and board.
	//	playersTurn=1 (white), playersTurn=0 (black)

	// Update the board
	
	int from = move.moveFrom;
	int to   = move.moveTo;

	board.board[to]   = board.board[from];
	board.board[from] = 0;
	board.canUndo     = 1;
	board.lastMove = move;
	
	// Handle castling first
	//	Note: the actual king movement will be handled in the following loop, here we just want to handle the rooks
	
	if (whitePieceList[0].location == from && to-from==2){ // we just castled with the white king kingside
		whitePieceList[3].location = 96; // h-file white rook
		whitePieceList[3].everMoved = 1;
		board.board[96] = 4;
		board.board[98] = 0;
	}

	if (whitePieceList[0].location == from && to-from==-2){ // we just castled with the white king queenside
		whitePieceList[2].location = 94; // a-file white rook
		whitePieceList[2].everMoved = 1;
		board.board[91] = 0;
		board.board[94] = 4;
	}

	if (blackPieceList[0].location == from && to-from==2){ // we just castled with the black king kingside
		blackPieceList[3].location = 26; // h-file black rook
		blackPieceList[3].everMoved = 1;
		board.board[26] = -4;
		board.board[28] = 0;
	}

	if (blackPieceList[0].location == from && to-from==-2){ // we just castled with the black king queenside
		blackPieceList[2].location = 24; // a-file black rook
		blackPieceList[2].everMoved = 1;
		board.board[21] = 0;
		board.board[24] = -4;
	}
	
	// Update the piece information
	for (int i=0; i<16; i++)
	{
		// Update any piece being captured
		if (to == whitePieceList[i].location)
		{
			board.capturedPiece = whitePieceList[i];
			board.material -= whitePieceList[i].value;
			whitePieceList[i].location = 0;
		}
		if (to == blackPieceList[i].location)
		{
			board.capturedPiece = blackPieceList[i];
			board.material += blackPieceList[i].value;
			blackPieceList[i].location = 0;
		}
		
		// Update any moving piece
		if (from == whitePieceList[i].location )
		{
			whitePieceList[i].location = to;
			board.pastEverMovedStatus = whitePieceList[i].everMoved;
			whitePieceList[i].everMoved = 1;
		}
		if (from == blackPieceList[i].location )
		{
			blackPieceList[i].location = to;
			board.pastEverMovedStatus = blackPieceList[i].everMoved;
			blackPieceList[i].everMoved = 1;
		}
	}

	// Update whose turn it is
	playersTurn = !playersTurn;
}

int undoMove(pieceClass whitePieceList[16], pieceClass blackPieceList[16], boardClass &board, int &playersTurn)
{
	// This function is meant to undo the last move. Captured piece information comes from the boardClass, thus
	//	only the most recent move can be undone. 
	//
	// The return value of this function designates whether the undo move was successful (1) or not (0).
	
	int undidMove = 0;

	if (board.canUndo) // Make sure we can undo the last move
	{

		int from = board.lastMove.moveFrom;
		int to   = board.lastMove.moveTo;

		// Update the board
		board.board[from] = board.board[to];
		board.board[to]   = board.capturedPiece.identity;
		
		// Handle castling
		//	Note: we just need to handle the rooks here, the kings will be handled later
		if (whitePieceList[0].location == to && to-from==2){ // we castled with the white king kingside
			whitePieceList[3].location = 98; // h-file white rook
			whitePieceList[3].everMoved = 0;
			board.board[96] = 0;
			board.board[98] = 4;
		}

		if (whitePieceList[0].location == to && to-from==-2){ // we castled with the white king queenside
			whitePieceList[3].location = 91; // a-file white rook
			whitePieceList[3].everMoved = 0;
			board.board[94] = 0;
			board.board[91] = 4;
		}

		if (blackPieceList[0].location == to && to-from==2){ // we castled with the black king kingside
			blackPieceList[3].location = 28; // h-file black rook
			blackPieceList[3].everMoved = 0;
			board.board[26] = 0;
			board.board[28] = -4;
		}

		if (blackPieceList[0].location == to && to-from==-2){ // we castled with the black king queenside
			blackPieceList[3].location = 21; // a-file black rook
			blackPieceList[3].everMoved = 0;
			board.board[24] = 0;
			board.board[21] = -4;
		}

		// Update piece information
		for (int i=0; i<16; i++)
		{
			// Move back the piece that moved
			if (to == whitePieceList[i].location)
			{
				whitePieceList[i].location = from;
				whitePieceList[i].everMoved = board.pastEverMovedStatus;

				// Restore any piece that was captured
				if (board.capturedPiece.location) // if there was a captured piece
				{
					blackPieceList[board.capturedPiece.index] = board.capturedPiece;
					board.capturedPiece.initializePiece(0,0,0,0,0,0);
				}
			}
			if (to == blackPieceList[i].location)
			{
				blackPieceList[i].location = from;
				blackPieceList[i].everMoved = board.pastEverMovedStatus;

				// Restore any piece that was captured
				if (board.capturedPiece.location)
				{
					whitePieceList[board.capturedPiece.index] = board.capturedPiece;
					board.capturedPiece.initializePiece(0,0,0,0,0,0);
				}
			}

		}

		// Undo whoever's turn it is
		playersTurn = !playersTurn;



		board.capturedPiece.initializePiece(0,0,0,0,0,0);
		board.canUndo = 0;
		undidMove = 1;
	}

	return undidMove;
}

int lazyEval(pieceClass whitePieceList[16], pieceClass blackPieceList[16], boardClass board)
{
	// This function returns an evaluation of one single board position. 
	//	Positive numbers favor white, negative numbers favor black.
	//
	// There are two parts of the lazy eval:
	//	1) material advantage
	//	2) positional advantage
	//
	// For (1) we add up the material difference between the sides, for (2) we use square tables
	//	to give bonuses for pieces on squares that are generally good for them.

	int eval;
	int matAdv, posAdv=0;

	// Material Advantage
	matAdv = board.material; // Easy, this information is actually kept on the board itself

	// Positional Advantage
	//	Kings
	posAdv += squareTables.kingTableMidW[whitePieceList[0].location];
	posAdv -= squareTables.kingTableMidB[blackPieceList[0].location];

	// Queens
	//	We currently don't care where queens go

	// Rooks
	//	We currently don't care where rooks go either
	
	// Bishops
	if (whitePieceList[4].location) // Make sure the bishop is still alive
		posAdv += squareTables.bishopTableW[whitePieceList[4].location];
	if (whitePieceList[5].location)
		posAdv += squareTables.bishopTableW[whitePieceList[5].location];
	if (blackPieceList[4].location)
		posAdv -= squareTables.bishopTableB[blackPieceList[4].location];
	if (blackPieceList[5].location)
		posAdv -= squareTables.bishopTableB[blackPieceList[5].location];

	// Knights
	if (whitePieceList[6].location) // Make sure the knight is still alive
		posAdv += squareTables.knightTableW[whitePieceList[6].location];
	if (whitePieceList[7].location)
		posAdv += squareTables.knightTableW[whitePieceList[7].location];
	if (blackPieceList[6].location) 
		posAdv -= squareTables.knightTableB[blackPieceList[6].location];
	if (blackPieceList[7].location)
		posAdv -= squareTables.knightTableB[blackPieceList[7].location];

	// Pawns
	for (int i=8; i<16; i++)
	{
		if (whitePieceList[i].location) // Make sure the pawn is still alive
			posAdv += squareTables.pawnTableW[whitePieceList[i].location];
		if (blackPieceList[i].location) // 
			posAdv -= squareTables.pawnTableB[blackPieceList[i].location];
	}

	// Eval
	eval = matAdv + posAdv;

	return eval;
}

void lazyEvalAllLegalMoves(pieceClass whitePieceList[16], pieceClass blackPieceList[16], boardClass &board, int player)
{
	// Evaluates all possible moves on the current board for a given player (1=white,-1=black) using a lazy eval.
	vector<moveStruct> legalMoveList;
	board.moveScores.clear();
	int numLegalMoves;
	if (player==1)
		numLegalMoves = generatePseudoLegalMoveList(board.board, legalMoveList, whitePieceList, player);
	else
		numLegalMoves = generatePseudoLegalMoveList(board.board, legalMoveList, blackPieceList, player);
	
	for (int i=0; i<numLegalMoves-1; i++)
	{
		makeMove(legalMoveList[i], whitePieceList, blackPieceList, board, playersTurn);
		board.moveScores.push_back(lazyEval(whitePieceList, blackPieceList, board));
		undoMove(whitePieceList, blackPieceList, board, playersTurn);
	}

	updateBoardLegalMoveList(legalMoveList, board);
}

void displayMoveScores(boardClass board)
{
	int numMoveScores = board.moveScores.size();
	for (int i=0; i<numMoveScores; i++)
	{
		printf("\n\t%d->%d: %d", board.legalMoves[i].moveFrom, board.legalMoves[i].moveTo, board.moveScores[i]);
	}
}

void updateBoardLegalMoveList(vector<moveStruct> legalMoveList, boardClass &board)
{
	board.legalMoves.clear();
	int numLegalMoves = legalMoveList.size();

	for (int i=0; i<numLegalMoves; i++)
	{
		board.legalMoves.push_back(legalMoveList[i]);
	}

}

int checkMoveLegality(moveStruct potentialMove, boardClass board, pieceClass whitePieceList[16], pieceClass blackPieceList[16], int player)
{
	// This function is meant to check the legality of a desired move. If the move is legal the function returns
	//	1, if the move is not legal the function returns 0
	//
	// player=1 (white), player=0 or player=-1 (black)

	int moveLegal = 0;
	vector<moveStruct> legalMoveList;

	// If player==0 we are referring to black. The generatePseudoLegalMoveList() function wants black to be -1
	if (!player)
		player = -1;

	
	int numLegalMoves;
	if (player==1)
		numLegalMoves = generatePseudoLegalMoveList(board.board, legalMoveList, whitePieceList, player);
	else 
		numLegalMoves = generatePseudoLegalMoveList(board.board, legalMoveList, blackPieceList, player);
	
	//int numLegalMoves = generateFullLegalMoveList(board, legalMoveList, whitePieceList, blackPieceList, player);

	for (int i=0; i<numLegalMoves; i++)
	{
		if (potentialMove.moveFrom==legalMoveList[i].moveFrom && potentialMove.moveTo==legalMoveList[i].moveTo)
			moveLegal = 1;
	}

	return moveLegal;
}