//
//  board.swift
//  Kingsmen Chess
//
//  Created by Jeremy on 5/11/15.
//  Copyright (c) 2015 Cypress Inc. All rights reserved.
//

import Foundation

func ==(lhs: Board, rhs: Board) -> Bool {
    return lhs.hashValue == rhs.hashValue
}

class Board: Hashable {
    // This class stores the complete board state. It does not care (or know) how this particular board state was reached.
    
    var board = [Int]() // The actual board array
    private var gameRecord = MoveList() // The game record (history of moves)
    var gameTree = GameTree() // The game tree
    var pieces = [Piece]() // The set of board pieces
    var toMove = String() // {"white", "black"}; who's move it is next
    var toMoveInt : Int { return (toMove=="white" ? 1 : -1) }
    var currentPly : Int { return gameRecord.moves.count }
    var fen : String { if fenStore==nil {computeFen()}; return fenStore! }
    private var fenStore : String? // The fen string that represents the current board
    private var rootBoard : Board? // We allow a Move to load the board to the root board, thus saving us from having to play all the moves to get there (and also allowing for faster fen string support)
    
    // Irreversible board information (board state information that cannot be gleamed directly from the board array itself).array
    //    I.e. the extra information needed to make an 'undo' move
    
    // en-passant
    var epSq : Int? // en-passant square; a pawn just double-pushed on the move before leaving behind an en-passant square (i.e. the square that was jumped over). When checking for legal moves pawns may push to this square (diagonally) to capture
    
    // promotions
    var pro : (move: Move, pieceId: Int)? // promotion; if there was a promotion last turn, the pieceId gives the piece's old id
    
    // Legal move lists (use their associated functions to access them)
    private var opponentsPseudoLegalMoveList : MoveList?
    private var pseudoLegalMoveList : MoveList?
    private var legalMoveList : MoveList?
    var bestMove: Move?
    
    // Check flag (is the player-to-move's king in check)
    var check : Bool?
    
    // Evaluation parameters
    var evalScore: Int? // The final evaluation score for this board position
    var materialScore: Int? // The combined material score of black and white  (positive material score means white has a material advantage, a negative socre the opposite)
    var positionScore: Int? // The combined position score of black and white
    var gamePhase : String { if pieces[14].location==0 && pieces[30].location==0 { return "End" } else { return "Mid" } }
    var pieceValues = Dictionary<String, Int>()
    
    var hashValue: Int { return computeHash() }
    
    func computeHash() -> Int {
        //return "\(fen)".hashValue
        
        var hashString = "\(fen)"
        for piece in pieces {
            hashString += "\(piece.type)\(piece.owner)\(piece.value)\(piece.location)\(piece.everMoved)\(piece.index)"
        }
        
        return hashString.hashValue
    }
    
    init () {
        initializeGameBoard()
    }
    
    init (board: Board) {
        self.board = board.board
        self.gameRecord = board.gameRecord
        self.gameTree = board.gameTree
        self.pieces = board.pieces
        self.toMove = board.toMove
        self.fenStore = board.fenStore
        self.rootBoard = board.rootBoard
        
        self.epSq = board.epSq
        self.pro = board.pro
        self.opponentsPseudoLegalMoveList = board.opponentsPseudoLegalMoveList
        self.pseudoLegalMoveList = board.pseudoLegalMoveList
        self.legalMoveList = board.legalMoveList
        self.bestMove = board.bestMove
        
        self.check = board.check
        
        self.evalScore = board.evalScore
        self.materialScore = board.materialScore
        self.positionScore = board.positionScore
        self.pieceValues = board.pieceValues
    }
    
    func copy(board: Board) {
        // This function takes the given board and makes the current board equivalent
        self.board = board.board
        self.gameRecord = board.gameRecord
        self.gameTree = board.gameTree
        self.pieces = board.pieces
        self.toMove = board.toMove
        self.fenStore = board.fenStore
        self.rootBoard = board.rootBoard
        
        self.epSq = board.epSq
        self.pro = board.pro
        self.opponentsPseudoLegalMoveList = board.opponentsPseudoLegalMoveList
        self.pseudoLegalMoveList = board.pseudoLegalMoveList
        self.legalMoveList = board.legalMoveList
        self.bestMove = board.bestMove
        
        self.check = board.check
        
        self.evalScore = board.evalScore
        self.materialScore = board.materialScore
        self.positionScore = board.positionScore
        self.pieceValues = board.pieceValues
    }
    
    convenience init (gameRecord: MoveList) {
        self.init()
        makeMoves(gameRecord)
    }
    
    convenience init (fen: String) {
        self.init()
        loadFen(fen)
    }
    
    convenience init (adrastos: Adrastos) {
        self.init()
        adrastos.initBoardForAI(self)
    }
    
    convenience init (gameRecord: MoveList, adrastos: Adrastos) {
        self.init(gameRecord: gameRecord)
        adrastos.initBoardForAI(self)
    }
    
    func loadFen(fen: String) {
        for piece in self.pieces {
            piece.location = 0
        }
        
        // Keep track of how many times we've seen a particular piece in the fen string
        var PInd = 0, POffset = 0
        var NInd = 0, NOffset = 8
        var BInd = 0, BOffset = 10
        var RInd = 0, ROffset = 12
        var QInd = 0, QOffset = 14
        var KInd = 0, KOffset = 15
        var pInd = 0, pOffset = 16
        var nInd = 0, nOffset = 24
        var bInd = 0, bOffset = 26
        var rInd = 0, rOffset = 28
        var qInd = 0, qOffset = 30
        var kInd = 0, kOffset = 31
        
        var loc = 0
        var strLoc = -1
        while loc < 64 {
            strLoc++
            switch String(fen[strLoc]) {
            case "P":
                pieces[PInd+POffset].location = sixtyFour2oneTwenty(loc)
                if sixtyFour2oneTwenty(loc)<std2ind("a2") {
                    var tempLoc = std2ind("a2")
                    pieces[PInd+POffset].moveCounter = nil } // If the pawn is not on the 2nd row then it has already moved
                loc++
                PInd++
            case "N":
                // If we have more than two knights, we need to start using some of the pawn pieces to store them
                if NInd<2 {
                    pieces[NInd+NOffset].location = sixtyFour2oneTwenty(loc)
                    loc++
                    NInd++
                } else {
                    pieces[PInd+POffset].location = sixtyFour2oneTwenty(loc)
                    pieces[PInd+POffset].type = "knight"
                    loc++
                    PInd++
                }
            case "B":
                if BInd<2 {
                    pieces[BInd+BOffset].location = sixtyFour2oneTwenty(loc)
                    loc++
                    BInd++
                } else {
                    pieces[PInd+POffset].location = sixtyFour2oneTwenty(loc)
                    pieces[PInd+POffset].type = "bishop"
                    loc++
                    PInd++
                }
            case "R":
                if RInd<2 {
                    pieces[RInd+ROffset].location = sixtyFour2oneTwenty(loc)
                    loc++
                    RInd++
                } else {
                    pieces[PInd+POffset].location = sixtyFour2oneTwenty(loc)
                    pieces[PInd+POffset].type = "rook"
                    loc++
                    PInd++
                }
            case "Q":
                if QInd<1 {
                    pieces[QInd+QOffset].location = sixtyFour2oneTwenty(loc)
                    loc++
                    QInd++
                } else {
                    pieces[PInd+POffset].location = sixtyFour2oneTwenty(loc)
                    pieces[PInd+POffset].type = "queen"
                    loc++
                    PInd++
                }
            case "K":
                pieces[KInd+KOffset].location = sixtyFour2oneTwenty(loc)
                loc++
                KInd++
            case "p":
                pieces[pInd+pOffset].location = sixtyFour2oneTwenty(loc)
                if sixtyFour2oneTwenty(loc)>std2ind("h7") { pieces[pInd+pOffset].moveCounter = nil } // If the pawn is not on the 2nd row then it has already moved
                loc++
                pInd++
            case "n":
                // If we have more than two knights, we need to start using some of the pawn pieces to store them
                if nInd<2 {
                    pieces[nInd+nOffset].location = sixtyFour2oneTwenty(loc)
                    loc++
                    nInd++
                } else {
                    pieces[pInd+pOffset].location = sixtyFour2oneTwenty(loc)
                    pieces[pInd+pOffset].type = "knight"
                    loc++
                    pInd++
                }
            case "b":
                if bInd<2 {
                    pieces[bInd+bOffset].location = sixtyFour2oneTwenty(loc)
                    loc++
                    bInd++
                } else {
                    pieces[pInd+pOffset].location = sixtyFour2oneTwenty(loc)
                    pieces[pInd+pOffset].type = "bishop"
                    loc++
                    pInd++
                }
            case "r":
                if rInd<2 {
                    pieces[rInd+rOffset].location = sixtyFour2oneTwenty(loc)
                    loc++
                    rInd++
                } else {
                    pieces[pInd+pOffset].location = sixtyFour2oneTwenty(loc)
                    pieces[pInd+pOffset].type = "rook"
                    loc++
                    pInd++
                }
            case "q":
                if qInd<1 {
                    pieces[qInd+qOffset].location = sixtyFour2oneTwenty(loc)
                    loc++
                    qInd++
                } else {
                    pieces[pInd+pOffset].location = sixtyFour2oneTwenty(loc)
                    pieces[pInd+pOffset].type = "queen"
                    loc++
                    pInd++
                }
            case "k":
                pieces[kInd+kOffset].location = sixtyFour2oneTwenty(loc)
                loc++
                kInd++
                
            case "1": loc += 1
            case "2": loc += 2
            case "3": loc += 3
            case "4": loc += 4
            case "5": loc += 5
            case "6": loc += 6
            case "7": loc += 7
            case "8": loc += 8
                
            case "/": break
                
            default: debugPrintln("Unknown fen string component found during board reconstruction", "board init with fen string")
            }
        }
        
        // Next there is an empty space followed by who's turn it is to move
        strLoc += 2
        switch String(fen[strLoc]) {
        case "w": self.toMove = "white"
        case "b": self.toMove = "black"
        default: debugPrintln("Uknown fen string component found during toMove parsing", "board init with fen string")
        }
        
        // Next come the castling rights
        strLoc += 2
        
        // We start off assuming we can't castle by setting both king's moveCounter to nil. If there are any castling rights these values will be changed.
        pieces[15].moveCounter = nil
        pieces[31].moveCounter = nil
        
        var moreCastlingRights = true
        while moreCastlingRights {
            moreCastlingRights = false
            switch String(fen[strLoc]) {
            case "-": // There are no castling rights available; the easiest way for us to make this true is to pretend as if each king has already moved
                pieces[15].moveCounter = nil // white king
                pieces[31].moveCounter = nil // black king
                strLoc++
            case " ": // There were castling rights but we have now seen them all, we needn't do anything
                break
            case "K": // The white king can castle kingside; this is slightly tricky as we have to find the rook at the square h1 (which is not necessarily stored at pieces[13] because of the way we loaded our pieces; e.g. if a pawn has promoted to a rook the rook at h1 could have been seen as the "third" rook and subsequently stored at the location of a promoted pawn (e.g. the desired rook might be stored at something like pieces[4]) instead). Note that it is assumed that if castling rights are given the board actually is set up to support those rights
                for piece in pieces {
                    if piece.location == std2ind("h1") && piece.type == "rook" {
                        piece.moveCounter = 0
                        break
                    }
                }
                pieces[15].moveCounter = 0 // white king
                strLoc++
                moreCastlingRights = true
            case "Q": // The white king can castle queenside
                for piece in pieces {
                    if piece.location == std2ind("a1") && piece.type == "rook" {
                        piece.moveCounter = 0
                        break
                    }
                }
                pieces[15].moveCounter = 0 // white king
                strLoc++
                moreCastlingRights = true
            case "k": // The black king can castle kingside
                for piece in pieces {
                    if piece.location == std2ind("h8") && piece.type == "rook" {
                        piece.moveCounter = 0
                        break
                    }
                }
                pieces[31].moveCounter = 0 // black king
                strLoc++
                moreCastlingRights = true
            case "q": // The black king can castle queenside
                for piece in pieces {
                    if piece.location == std2ind("a8") && piece.type == "rook" {
                        piece.moveCounter = 0
                        break
                    }
                }
                pieces[31].moveCounter = 0 // black king
                strLoc++
                moreCastlingRights = true
                
            default: break
            }
        }
        
        // We are now located at the space after the castling rights. Next there is either a two-character en-passant square (e.g. "c6") or a one-character hyphon
        strLoc++
        switch String(fen[strLoc]) {
        case "-": break // we don't need to do anything
        default: // there is an en-passant square listed
            self.epSq = std2ind(fen[strLoc...(strLoc+1)])
        }
        
        // Next come the halfmove clock (the number of moves since the last capture or pawn advance) and the fullmove number. We don't use either
        
        // Next we sync the board to the pieces
        syncBoardFromPieces()
        
        // Finally we need to set the gameRecord to start with this position
        gameRecord.moves.append(Move(fen: fen))
        //gameRecord.moves.append(Move(board: self))
    }
    
    private func computeFen() -> String {
        var fen = String()
        
        var spaceCounter = 0
        func insertSpace() {
            fen = fen + "\(spaceCounter)"
            spaceCounter = 0
        }
        
        var colCounter = 0
        for i in 0...63 {
            switch board[sixtyFour2oneTwenty(i)] {
                case 0:
                    spaceCounter++
                case 1:
                    if spaceCounter > 0 { insertSpace() }
                    fen += "P"
                case 2:
                    if spaceCounter > 0 { insertSpace() }
                    fen += "N"
                case 3:
                    if spaceCounter > 0 { insertSpace() }
                    fen += "B"
                case 4:
                    if spaceCounter > 0 { insertSpace() }
                    fen += "R"
                case 5:
                    if spaceCounter > 0 { insertSpace() }
                    fen += "Q"
                case 6:
                    if spaceCounter > 0 { insertSpace() }
                    fen += "K"
                case -1:
                    if spaceCounter > 0 { insertSpace() }
                    fen += "p"
                case -2:
                    if spaceCounter > 0 { insertSpace() }
                    fen += "n"
                case -3:
                    if spaceCounter > 0 { insertSpace() }
                    fen += "b"
                case -4:
                    if spaceCounter > 0 { insertSpace() }
                    fen += "r"
                case -5:
                    if spaceCounter > 0 { insertSpace() }
                    fen += "q"
                case -6:
                    if spaceCounter > 0 { insertSpace() }
                    fen += "k"
                default: debugPrintln("Something has gone wrong with board->fen string conversion")
            }
            colCounter++
            if colCounter==8 {
                if spaceCounter>0 {insertSpace()}
                if i<63 { fen = fen + "/" }
                colCounter = 0
            }
        }
        
        // Next there is a space followed by who's turn it is to move 
        (toMove == "white") ? (fen += " w ") : (fen += " b ")
        
        // Next are the castling rights
        var needSpace = false
        if pieces[15].everMoved==false { // If the white king has never moved
            for piece in pieces {
                if piece.location == std2ind("h1") && piece.type == "rook" && piece.everMoved==false {
                    fen += "K"
                    needSpace = true
                    break
                }
            }
            for piece in pieces {
                if piece.location == std2ind("a1") && piece.type == "rook" && piece.everMoved==false {
                    fen += "Q"
                    needSpace = true
                    break
                }
            }
        }
        if pieces[31].everMoved==false { // If the black king has never moved
            for piece in pieces {
                if piece.location == std2ind("h8") && piece.type == "rook" && piece.everMoved==false {
                    fen += "k"
                    needSpace = true
                    break
                }
            }
            for piece in pieces {
                if piece.location == std2ind("a8") && piece.type == "rook" && piece.everMoved==false {
                    fen += "q"
                    needSpace = true
                    break
                }
            }
        }
        if needSpace { fen += " " }
        
        // Next comes the en-passant square
        if epSq == nil {
            fen += "-"
        } else {
            fen += ind2std(epSq!)
        }
        
        // Next comes the half-move clock and full move. Since we don't use these we put in fake values
        fen += " 0 1"
        
        // Save the fen string to our internal fen variable so we won't have to compute it again if requested
        fenStore = fen
        
        return fen
    }
    
    func perft(fen: String, depth: Int) {
        loadFen(fen)
        perft(depth)
    }
    
    func perft(depth: Int) {
        // This function computes all moves from the current position for the given depth. We organize the results by the number of end nodes for each move at the current node.
        
        debugPrintln("Computing Perft(\(depth))")
        var total = 0, nodeCount = 0
        switch depth {
            case 0:
                total = 1
            case 1:
                printLegalMoveList()
                total = getLegalMoveList().moves.count
            default:
                for move in getLegalMoveList().moves {
                    makeMove(move)
                    nodeCount = perftHelper(self, depth: depth-1)
                    //undoMove()
                    undoMove(move)
                    //undoMoveTest(move)
                    
                    debugPrintln("\(ind2std(move.from)) -> \(ind2std(move.to)) : \(nodeCount)")
                    total += nodeCount
            }
        }
        debugPrintln("Total: \(total)\n")
        
    }
    
    func perftHelper(board: Board, depth: Int) -> Int {
        if depth == 1 { // One means this is the final non-terminal depth, just return the number of moves here, we don't need to look any further
            return board.getLegalMoveList().moves.count
        } else if board.getLegalMoveList().moves.count==0 { // we don't count nodes that don't reach the terminal depth
            return 0
        } else {
            var total = 0
            for move in board.getLegalMoveList().moves {
                board.makeMove(move)
                total += perftHelper(board, depth: depth-1)
                //board.undoMove()
                board.undoMove(move)
                //board.undoMoveTest(move)
            }
            return total
        }
        
    }
    
    func initializeGameBoard() {
        // This function should initialize an entirely new board to start a game
        
        board  = [-99, -99, -99, -99, -99, -99, -99, -99, -99, -99,
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
            -99, -99, -99, -99, -99, -99, -99, -99, -99, -99]
        epSq  = nil
        pro = nil
        
        // Initialize AI if desired
        
        
        // Initialize white to move
        toMove = "white"
        
        // Initialize an empty game record
        gameRecord = MoveList()
        
        // Set the fenStore to nil
        fenStore = nil
        
        // Reset the legal move lists
        pseudoLegalMoveList = nil
        legalMoveList = nil
        opponentsPseudoLegalMoveList = nil
        
        // When the game starts we are not in check
        check = false
        
        // Reset all evaluations
        evalScore = nil
        materialScore = nil
        positionScore = nil
        
        // Initialize a full set of pieces
        pieces = [Piece]()
        
        //   White Pawns
        for i in 0...7 {
            pieces.append(Piece(type: "pawn", location: 81+i, owner: "white", index: i))
        }
        
        //  White Knights
        pieces.append(Piece(type: "knight", location: 92, owner: "white", index: 8))
        pieces.append(Piece(type: "knight", location: 97, owner: "white", index: 9))
        
        //  White Bishops
        pieces.append(Piece(type: "bishop", location: 93, owner: "white", index: 10))
        pieces.append(Piece(type: "bishop", location: 96, owner: "white", index: 11))
        
        //  White Rooks
        pieces.append(Piece(type: "rook", location: 91, owner: "white", index: 12))
        pieces.append(Piece(type: "rook", location: 98, owner: "white", index: 13))
        
        //  White Queen and King
        pieces.append(Piece(type: "queen", location: 94, owner: "white", index: 14))
        pieces.append(Piece(type: "king", location: 95, owner: "white", index: 15))
        
        //  Black Pawns
        for i in 0...7 {
            pieces.append(Piece(type: "pawn", location: 31+i, owner: "black", index: 16+i))
        }
        
        //  Black Knights
        pieces.append(Piece(type: "knight", location: 22, owner: "black", index: 24))
        pieces.append(Piece(type: "knight", location: 27, owner: "black", index: 25))
        
        //  Black Bishops
        pieces.append(Piece(type: "bishop", location: 23, owner: "black", index: 26))
        pieces.append(Piece(type: "bishop", location: 26, owner: "black", index: 27))
        
        //  Black Rooks
        pieces.append(Piece(type: "rook", location: 21, owner: "black", index: 28))
        pieces.append(Piece(type: "rook", location: 28, owner: "black", index: 29))
        
        // Black Queen and King
        pieces.append(Piece(type: "queen", location: 24, owner: "black", index: 30))
        pieces.append(Piece(type: "king", location: 25, owner: "black", index: 31))
        
        // Go back through and reset any values initialized from an ai for each piece
        for piece in pieces { piece.value = pieceValues[piece.type] }
        
    }
    
    func initializeGameBoard(gameRecord: MoveList) {
        initializeGameBoard()
        makeMoves(gameRecord)
    }
    
    func printPiecesInformation() {
        for piece in pieces {
            printPieceInformation(piece)
        }
        debugPrintln("", "piece information")
    }
    
    func printPieceInformation(piece: Piece) {
        debugPrintln("\(piece.index) : \(piece.owner) \(piece.type), location: \(ind2std(piece.location)), value: \(piece.value?), everMoved: \(piece.everMoved)", "piece information")
    }
    
    func printBoard() {
        let rows = "87654321"
        let cols = "abcdefgh"
        
        for i: Int in 2...9 {
            var rowString: String = rows[i-2] + " "
            for j: Int in 1...8 {
                rowString += getPieceChar(board[coords2ind(i,col: j)])
                //rowString += "\(board[coords2ind(i,col: j)])" + "(" + "\(i)" + "," + "\(j)" + "->" + "\(coords2ind(i, col: j))" + ") "
            }
            debugPrintln(rowString,"board")
        }
        debugPrintln("\n  \(cols) \n", "board")
    }
    
    func printPseudoLegalMoveList() {
        debugPrintln("Psuedo-Legal Move List (\(getPseudoLegalMoveList().moves.count) moves total): ", "printPseudoLegalMoveList")
        printMoveList(getPseudoLegalMoveList())
    }
    
    func printLegalMoveList() {
        debugPrintln("Legal Move List (\(getLegalMoveList().moves.count) moves total): ", "printLegalMoveList")
        printMoveList(getLegalMoveList())
    }
    
    func printMoveList(moveList: MoveList) {
        for move in moveList.moves {
            var valueString = ((move.evalScore==nil) ? "" : " (evalScore: \(move.evalScore!))")
            
            if move.pro == nil {
                if move.epCap != nil {
                    debugPrintln(ind2std(move.from) + " -> " + ind2std(move.to) + valueString + " (en-passant capture)", "printMoveList")
                } else {
                    debugPrintln(ind2std(move.from) + " -> " + ind2std(move.to) + valueString, "printMoveList")
                }
            } else {
                debugPrintln(ind2std(move.from) + " -> " + ind2std(move.to) + valueString + " (\(move.pro!) promotion)" , "printMoveList")
            }
        }
        debugPrintln("", "printMoveList")
    }
    
    func printMove(move: Move) {
        // Just make a MoveList with the one move in it and print it out
        var moveList = MoveList()
        moveList.moves.append(move)
        printMoveList(moveList)
    }
    
    func syncBoardFromPieces() {
        // This function resets the board according to the current information stored in the pieces array
        board  = [-99, -99, -99, -99, -99, -99, -99, -99, -99, -99,
                  -99, -99, -99, -99, -99, -99, -99, -99, -99, -99,
                  -99,   0,   0,   0,   0,   0,   0,   0,   0, -99,
                  -99,   0,   0,   0,   0,   0,   0,   0,   0, -99,
                  -99,   0,   0,   0,   0,   0,   0,   0,   0, -99,
                  -99,   0,   0,   0,   0,   0,   0,   0,   0, -99,
                  -99,   0,   0,   0,   0,   0,   0,   0,   0, -99,
                  -99,   0,   0,   0,   0,   0,   0,   0,   0, -99,
                  -99,   0,   0,   0,   0,   0,   0,   0,   0, -99,
                  -99,   0,   0,   0,   0,   0,   0,   0,   0, -99,
                  -99, -99, -99, -99, -99, -99, -99, -99, -99, -99,
                  -99, -99, -99, -99, -99, -99, -99, -99, -99, -99]
        for piece in pieces {
            board[piece.location] = piece.intType
        }
    }
    
    func ind2coords(ind: Int) -> (row: Int, col: Int) {
    // This function converts an index (integer from 0 to 119) into row (0-11) and col (0-9) coordinates
        var row = ind/10
        var col = ind - row*10
        return (row, col)
    }
    
    func coords2ind(row: Int, col: Int) -> Int {
    // This function reverses ind2coords
        var ind = row*10 + col
        return ind
    }
    
    func ind2std(ind: Int) -> String {
        // index to standard ("a1", "e4", ect.) conversion
        
        if ind==0 {return "--"}
        
        let rows = "87654321"
        let cols = "abcdefgh"
        var row: Int, col: Int
        (row, col) = ind2coords(ind)
        
        //debugPrintln("cols: \(cols) rows: \(rows) col: \(col) row: \(row) ind: \(ind)")
        
        return (cols[col-1] + rows[row-2]) // don't forget to remove the extra column on the left and the two extra rows on the top
    }
    
    func sixtyFour2oneTwenty(ind: Int) -> Int {
        var row = ind/8
        var col = ind - row*8
        
        return (row+2)*10 + col+1
    }
    
    func oneTwenty2sixtyFour(ind: Int) -> Int {
        var row: Int, col: Int
        (row, col) = ind2coords(ind)
        
        return (row-2)*8 + col-1
    }
    
    func std2coords(std: String) -> (row: Int, col: Int) {
        // standard to coordinates
        
        var row = Int()
        var col = Int()
        
        var r: String = std[0], c: String = std[1]
        
        switch r {
            case "a": col = 1
            case "b": col = 2
            case "c": col = 3
            case "d": col = 4
            case "e": col = 5
            case "f": col = 6
            case "g": col = 7
            case "h": col = 8
            default: break
        }
        
        switch c {
            case "8": row = 2
            case "7": row = 3
            case "6": row = 4
            case "5": row = 5
            case "4": row = 6
            case "3": row = 7
            case "2": row = 8
            case "1": row = 9
            default: break
        }
        
        return (row, col)
    }
    
    func std2ind(std: String) -> Int {
        var row: Int, col: Int
        (row, col) = std2coords(std)
        
        return row*10 + col 
        
    }
    
    func getPieceChar(pieceId: Int) -> String {
    // This function returns the single character name for a given piece
        switch pieceId {
            case 0: return "-"
            case 1: return "P"
            case 2: return "N"
            case 3: return "B"
            case 4: return "R"
            case 5: return "Q"
            case 6: return "K"
            case -1: return "p"
            case -2: return "n"
            case -3: return "b"
            case -4: return "r"
            case -5: return "q"
            case -6: return "k"
            default: return ""
        }
    }
    
    func getPseudoLegalMoveList() -> MoveList {
        if pseudoLegalMoveList == nil { computePseudoLegalMoveList() }
       
        return pseudoLegalMoveList!
    }
    
    func getOpponentsPseudoLegalMoveList() -> MoveList {
        if opponentsPseudoLegalMoveList == nil {computeOpponentsPseudoLegalMoveList() }
        
        return opponentsPseudoLegalMoveList!
    }
    
    func getLegalMoveList() -> MoveList {
        if legalMoveList == nil { computeLegalMoveList() }
        
        return legalMoveList!
    }
    
    func setLegalMoveList(legalMoveList: MoveList) {
        self.legalMoveList = legalMoveList
    }
    
    func sortLegalMoveList() {
        // This function sorts all the legal moves according to their evaulation score. Note all moves in the legal move list need to have been evaluated previously. 
        if toMove=="white" { getLegalMoveList().moves.sort {$0.evalScore! > $1.evalScore!} }
        else { getLegalMoveList().moves.sort {$0.evalScore! < $1.evalScore!} }
    }
    
    private func computePseudoLegalMoveList() {
        pseudoLegalMoveList = computePseudoLegalMoveList((toMove=="white") ? "white" : "black")
    }
    
    private func computePseudoLegalMoveList(toMove: String) -> MoveList {
        
        var pseudoLegalMoveList : MoveList? = MoveList()
        var from: Int, to: Int
        var toMoveInt = (toMove=="white") ? 1 : -1
        
        for piece in pieces {
            from = piece.location
            if from == 0 || piece.intColor != toMoveInt { continue }
            
            switch piece.type {
                
            case "pawn":
                // Can the pawn move forward one space?
                //to   = from - piece.intColor*10
                to   = from - toMoveInt*10
                var row: Int
                //debugPrintln("location: \(from), looking to move to: \(to)", "computePseudoLegalMoveList")
                
                if board[to] == 0 {
                    (row,_) = ind2coords(to)
                    if row==2 || row==9 { // If we're moving to the final rank, we're promoting
                        pseudoLegalMoveList!.moves.append(Move(from: from, to: to, pro: "knight", fromId: piece.index))
                        pseudoLegalMoveList!.moves.append(Move(from: from, to: to, pro: "bishop", fromId: piece.index))
                        pseudoLegalMoveList!.moves.append(Move(from: from, to: to, pro: "rook", fromId: piece.index))
                        pseudoLegalMoveList!.moves.append(Move(from: from, to: to, pro: "queen", fromId: piece.index))
                    } else { // otherwise it's just a normal move
                        pseudoLegalMoveList!.moves.append(Move(from: from, to: to, fromId: piece.index))
                        
                        // If we could move forward one, can we move forward two spaces?
                        to = from - piece.intColor*20
                        //debugPrintln("location: \(from), looking to move to: \(to)", "computePseudoLegalMoveList")
                        
                        if !piece.everMoved && board[to] == 0 {
                            pseudoLegalMoveList!.moves.append(Move(from: from, to: to, epSq: from-piece.intColor*10, fromId: piece.index))
                            //println("Setting \(ind2std(from-piece.intColor*10)) as the en-passant square for move \(ind2std(from)) -> \(ind2std(to))")
                        }
                    }
                }
                
                // Can the pawn move diagonally left?
                //to = from - piece.intColor*9
                to = from - toMoveInt*9
                //debugPrintln("location: \(from), looking to move to: \(to)", "computePseudoLegalMoveList")
                //if board[to]*piece.intColor < 0 && board[to] != -99 { // i.e. if there is a piece at the diagonal location (board[to]!=0) and that piece is a different color (board[to]!=piece.intColor) then we can capture the piece
                if board[to]*toMoveInt < 0 && board[to] != -99 { // i.e. if there is a piece at the diagonal location (board[to]!=0) and that piece is a different color (board[to]!=piece.intColor) then we can capture the piece
                    (row,_) = ind2coords(to)
                    if row==2 || row==9 {
                        pseudoLegalMoveList!.moves.append(Move(from: from, to: to, pro: "knight", fromId: piece.index))
                        pseudoLegalMoveList!.moves.append(Move(from: from, to: to, pro: "bishop", fromId: piece.index))
                        pseudoLegalMoveList!.moves.append(Move(from: from, to: to, pro: "rook", fromId: piece.index))
                        pseudoLegalMoveList!.moves.append(Move(from: from, to: to, pro: "queen", fromId: piece.index))
                    } else {
                        pseudoLegalMoveList!.moves.append(Move(from: from, to: to, fromId: piece.index))
                    }
                } else if to == epSq { // check en-passant square
                    //pseudoLegalMoveList!.moves.append(Move(from: from, to: to, epCap: epSq!+10*piece.intColor, fromId: piece.index))
                    pseudoLegalMoveList!.moves.append(Move(from: from, to: to, epCap: epSq!+10*toMoveInt, fromId: piece.index))
                }
                
                // Can the pawn move diagonally right?
                to = from - piece.intColor*11
                //debugPrintln("location: \(from), looking to move to: \(to)", "computePseudoLegalMoveList")
                //if board[to]*piece.intColor < 0 && board[to] != -99 {
                if board[to]*toMoveInt < 0 && board[to] != -99 {
                    (row,_) = ind2coords(to)
                    if row==2 || row==9 {
                        pseudoLegalMoveList!.moves.append(Move(from: from, to: to, pro: "knight", fromId: piece.index))
                        pseudoLegalMoveList!.moves.append(Move(from: from, to: to, pro: "bishop", fromId: piece.index))
                        pseudoLegalMoveList!.moves.append(Move(from: from, to: to, pro: "rook", fromId: piece.index))
                        pseudoLegalMoveList!.moves.append(Move(from: from, to: to, pro: "queen", fromId: piece.index))
                    } else {
                        pseudoLegalMoveList!.moves.append(Move(from: from, to: to, fromId: piece.index))
                    }
                } else if to == epSq {
                    //pseudoLegalMoveList!.moves.append(Move(from: from, to: to, epCap: epSq!+10*piece.intColor, fromId: piece.index))
                    pseudoLegalMoveList!.moves.append(Move(from: from, to: to, epCap: epSq!+10*toMoveInt, fromId: piece.index))
                }
                
            case "knight":
                for offset in moveOffsets.knight {
                    to = from + offset
                    //if board[to]*piece.intColor <= 0 && board[to] != -99 { // If we're not trying to move to a square with our own piece on it or is off the board
                    if board[to]*toMoveInt <= 0 && board[to] != -99 { // If we're not trying to move to a square with our own piece on it or is off the board
                        pseudoLegalMoveList!.moves.append(Move(from: from, to: to, fromId: piece.index))
                    }
                }
                
            case "bishop":
                for offset in moveOffsets.bishop {
                    var dist = 0
                    var pathClear = true
                    
                    while pathClear {
                        dist++
                        pathClear = false
                        
                        to = from + offset*dist
                        //if board[to]*piece.intColor <= 0 && board[to] != -99 {
                        if board[to]*toMoveInt <= 0 && board[to] != -99 {
                            pseudoLegalMoveList!.moves.append(Move(from: from, to: to, fromId: piece.index))
                            
                            if board[to] == 0 { // we can only keep moving if this move is not a capture
                                pathClear = true
                            }
                        }
                    }
                }
                
            case "rook":
                for offset in moveOffsets.rook {
                    var dist = 0
                    var pathClear = true
                    
                    while pathClear {
                        dist++
                        pathClear = false
                        
                        to = from + offset*dist
                        //if board[to]*piece.intColor <= 0 && board[to] != -99 {
                        if board[to]*toMoveInt <= 0 && board[to] != -99 {
                            pseudoLegalMoveList!.moves.append(Move(from: from, to: to, fromId: piece.index))
                            
                            if board[to] == 0 { // we can only keep moving if this move is not a capture
                                pathClear = true
                            }
                        }
                    }
                }
                
            case "queen":
                for offset in moveOffsets.queen {
                    var dist = 0
                    var pathClear = true
                    
                    while pathClear {
                        dist++
                        pathClear = false
                        
                        to = from + offset*dist
                        //if board[to]*piece.intColor <= 0 && board[to] != -99 {
                        if board[to]*toMoveInt <= 0 && board[to] != -99 {
                            pseudoLegalMoveList!.moves.append(Move(from: from, to: to, fromId: piece.index))
                            
                            if board[to] == 0 { // we can only keep moving if this move is not a capture
                                pathClear = true
                            }
                        }
                    }
                }
                
            case "king":
                for offset in moveOffsets.king {
                    to = from + offset
                    //if board[to]*piece.intColor <= 0 && board[to] != -99 { // If we're not trying to move to a square with our own piece on it or is off the board
                    if board[to]*toMoveInt <= 0 && board[to] != -99 { // If we're not trying to move to a square with our own piece on it or is off the board
                        pseudoLegalMoveList!.moves.append(Move(from: from, to: to, fromId: piece.index))
                    }
                }
                
                // Note: Add castling next
                if !piece.everMoved { // if the king has never moved
                    var rookId : Int
                    
                    // queenside (a-file) castle
                    to = from - 2
                    //(piece.owner == "white") ? (rookId = 12) : (rookId = 28)
                    (toMoveInt == 1) ? (rookId = 12) : (rookId = 28)
                    
                    if !pieces[rookId].everMoved && board[from-1]==0 && board[from-2]==0 && board[from-3]==0 { // If the rook has never moved and there are no intervening pieces (note we do NOT check for castling through check here)
                        pseudoLegalMoveList!.moves.append(Move(from: from, to: to, castling: (piece.index, rookId), fromId: piece.index))
                    }
                    
                    // kingside (h-file) castle
                    to = from + 2
                    //(piece.owner == "white") ? (rookId = 13) : (rookId = 29)
                    (toMoveInt == 1) ? (rookId = 13) : (rookId = 29)
                    
                    if !pieces[rookId].everMoved && board[from+1]==0 && board[from+2]==0 {
                        pseudoLegalMoveList!.moves.append(Move(from: from, to: to, castling: (piece.index, rookId), fromId: piece.index))
                    }
                }
                
            default: break
            }
        }
        
        return pseudoLegalMoveList!
    }
    
    private func computeOpponentsPseudoLegalMoveList() {
        opponentsPseudoLegalMoveList = computePseudoLegalMoveList((toMove=="white") ? "black" : "white")
    }
    
    private func computeLegalMoveList() {
        // Make sure that the pseudoLegalMoveList has already been computed
        getPseudoLegalMoveList()
        
        // Generate a test board to test moves on
        var testBoard = Board(gameRecord: gameRecord) // WARNING: Doesn't work if we loaded a game from a FEN string
        
        // Go through the pseudoLegalMoveList and see which ones don't end up with us in check 
        legalMoveList = MoveList()
        for move in pseudoLegalMoveList!.moves {
            
            //if move.from==std2ind("b5") && move.to==std2ind("b6") {
            //    println("We have a problem")
            //}
            
            testBoard.makeMove(move)
            
            //debugPrintln("About to check move \(ind2std(move.from))->\(ind2std(move.to))")
            //testBoard.printBoard()
            
            // Check to make sure we're not in check
            if !testBoard.inCheckForColor(self.toMove) { // self.toMove means board.toMove, NOT testBoard.toMove
                
                // If the move was a castling move, we have to make sure we didn't move through check either
                if move.castling != nil {
                    if !testBoard.canAttackSquare(testBoard.toMove, sq: (move.from+move.to)/2) && !testBoard.canAttackSquare(testBoard.toMove, sq: move.from) {
                        legalMoveList!.moves.append(move)
                    }
                } else {
                    legalMoveList!.moves.append(move)
                }
            }
            
            // Undo the move we made
            //testBoard.undoMove()
            testBoard.undoMove(move)
        }
    }
    
    func canAttackSquare(color: String, sq: Int) -> Bool {
        // This function looks to see if the given square can be attacked at all by the given color. 
        
        var canAttack = false
        if color != toMove {
            getOpponentsPseudoLegalMoveList()
            
            for move in opponentsPseudoLegalMoveList!.moves {
                if sq == move.to {
                    canAttack = true
                    break
                }
            }
        } else {
            getPseudoLegalMoveList()
            
            for move in pseudoLegalMoveList!.moves {
                if sq == move.to {
                    canAttack = true
                    break
                }
            }
        }
        
        return canAttack
    }
    
    func inCheckForColor(color: String) -> Bool {
        // This function tests to see if the given color's king can be captured as the board stands if it were the opponent's turn to move
        
        var kingLocation = ((color=="white") ? pieces[15].location : pieces[31].location )
        var colorToAttack = ((color=="white") ? "black" : "white")
        
        //println("The \(color) king is located at: \(ind2std(kingLocation))")
        //let does = "does", doesNot = "does not"
        //println("This move \(canAttackSquare(colorToAttack, sq: kingLocation) ? does : doesNot) result in check\n")
        
        return canAttackSquare(colorToAttack, sq: kingLocation)
    }
    
    func inCheckAtSquare(sq: Int) -> Bool {
        // This function checks whether the given square is capturable by the opponent. A hypothetical square may be given (as opposed to just using the location of the king) for purposes of checking castling legality
        return canAttackSquare((toMove=="white") ? "black" : "white", sq: sq)
    }
    
    func makeMove(move: Move) {
        
        // We check a few special "legal" moves
        if move.rootBoard != nil {
            copy(move.rootBoard!)
            return
        }
        
        if move.fen != nil {
            loadFen(move.fen!)
            return
        }
        
        // Otherwise we are making a normal move (i.e. at least one piece is moving from someplace to someplace else)
        
        // Make sure the move has the requisite piece ids
        move.getIds(pieces)
        
        // Update the pieces on the board
        if move.castling != nil { // if we're castling
            // Get all the squares the king and rook are moving to/from
            let kingFrom = move.from
            let kingTo   = move.to
            let rookFrom = pieces[move.castling!.rookId].location
            let rookTo   = (kingFrom + kingTo) / 2
            
            // Update the board
            board[kingTo]   = pieces[move.castling!.kingId].intType
            board[kingFrom] = 0
            board[rookTo]   = pieces[move.castling!.rookId].intType
            board[rookFrom] = 0
            
            // Update the piece being moved
            pieces[move.castling!.kingId].location  = kingTo
            pieces[move.castling!.kingId].moveCounter = 1
            pieces[move.castling!.rookId].location  = rookTo
            pieces[move.castling!.rookId].moveCounter = 1
            
        } else { // else its just a normal move
            // If this is a pawn promotion, change the pawn to its new piece type
            if move.pro != nil {
                pieces[move.fromId!].type = move.pro!
                pieces[move.fromId!].value = pieceValues[pieces[move.fromId!].type]
            }
            
            // Copy over the ep square
            epSq = move.epSq
            
            // Update the board itself
            board[move.to]   = pieces[move.fromId!].intType
            board[move.from] = 0
            if move.epCap != nil { board[move.epCap!] = 0 }
            
            // Update the piece being moved
            pieces[move.fromId!].location = move.to
            pieces[move.fromId!].moveCounter?++
            
            // Update any piece that is getting captured
            if move.toId != nil { pieces[move.toId!].location = 0 }
        }
        
        // Clear the legal move lists
        pseudoLegalMoveList = nil
        legalMoveList = nil
        opponentsPseudoLegalMoveList = nil
        
        // Clear the stored fen string
        fenStore = nil
        
        // Switch who's turn it is to move
        (toMove == "white") ? (toMove = "black") : (toMove = "white")
        
        // Add the move to the game record
        gameRecord.moves.append(move)
        
        // Make sure the game tree is also in sync 
        //gameTree.syncBoard(self)
    }
    
    func undoMove(move: Move) {
        // NOTE: The perft results with this function are in the ballpark but ultimimately not correct.
        
        // Update the pieces on the board
        if move.castling != nil { // if we castled
            let kingFrom = move.from
            let kingTo   = move.to
            var rookFrom: Int; if kingFrom > kingTo {rookFrom = kingFrom - 4 } else {rookFrom = kingFrom + 3} //pieces[move.castling!.rookId].location
            let rookTo   = (kingFrom + kingTo) / 2
            
            // Update the board
            board[kingTo]   = 0
            board[kingFrom] = pieces[move.castling!.kingId].intType
            board[rookTo]   = 0
            board[rookFrom] = pieces[move.castling!.rookId].intType
            
            // Update the piece being moved
            pieces[move.castling!.kingId].location  = kingFrom
            pieces[move.castling!.kingId].moveCounter?--
            pieces[move.castling!.rookId].location  = rookFrom
            pieces[move.castling!.rookId].moveCounter?--
            
        } else { // if we had a more "normal" move (piece move, piece capture, en-passant capture, or pawn promotion)
            // If the last move was a pawn promotion, change the pawn back into a pawn 
            if move.pro != nil {
                pieces[move.fromId!].type = "pawn"
                pieces[move.fromId!].value = pieceValues[pieces[move.fromId!].type]
            }
            
            // If we captured a piece we need to bring it back
            if move.toId != nil { // if we captured a piece
                if move.epCap != nil { // and if that captured piece was an en-passant capture
                    pieces[move.toId!].location = move.epCap!
                    board[move.epCap!] = pieces[move.toId!].intType
                    board[move.to] = 0
                } else { // if it was just a normal capture
                    pieces[move.toId!].location = move.to
                    board[move.to] = pieces[move.toId!].intType
                }
            } else { // if we didn't capture a piece
                board[move.to] = 0
            }
            
            // Recall the en-passant square from the previous board position
            epSq = gameRecord.moves[currentPly-1].getEpSq()
            
            // Update the moving piece 
            pieces[move.fromId!].location = move.from
            pieces[move.fromId!].moveCounter?--
            board[move.from] = pieces[move.fromId!].intType
            
        }
        
        // Clear the legal move lists
        pseudoLegalMoveList = nil
        legalMoveList = nil
        opponentsPseudoLegalMoveList = nil
        
        // Clear the evaluation scores
        evalScore = nil
        materialScore = nil
        positionScore = nil
        
        // Clear the stored fen string
        fenStore = nil
        
        // Switch who's turn it is to move
        (toMove == "white") ? (toMove = "black") : (toMove = "white")
        
        // Add the move to the game record
        gameRecord.moves.removeLast()
        
    }
    
    func undoLastMove() {
        undoMove(gameRecord.moves.last!)
    }
    
    func makeMoves(moveList: MoveList) {
        // This function plays a set of moves. It is assumed that all moves being played are legal.
        
        for move in moveList.moves {
            makeMove(move)
        }
        
    }
    
    func undoMove() {
        // Save a temp copy of the game record
        var tempGameRecord = gameRecord
        
        // Re-initialize the board
        initializeGameBoard()
        
        // Play through the game record up until the last move
        tempGameRecord.moves.removeLast()
        makeMoves(tempGameRecord)
    }
    
    func undoMoveTest(move: Move) {
        // This function undoes the last move, but is meant to test that undoMove() and undoMove(move) return the same result
        
        var testBoard = Board(board: self)
        
        self.undoMove()
        testBoard.undoMove(move)
        
        if (self != testBoard) {
            debugPrintln("Board unmatch for move \(ind2std(move.from))->\(ind2std(move.to))")
            debugPrintln("\tundoMove(): \(self.fen)")
            self.printBoard()
            debugPrintln("\tundoMove(move): \(testBoard.fen)")
            testBoard.printBoard()
            
            for index in 0...31 {
                if self.pieces[index] != testBoard.pieces[index] {
                    debugPrintln("Piece location for piece \(index) does not match!")
                    debugPrintln("undoMove():"); printPieceInformation(self.pieces[index])
                    debugPrintln("undoMove(move):"); printPieceInformation(testBoard.pieces[index])
                }
            }
        }
    }
    
    var moveOffsets = MoveOffsets()
    struct MoveOffsets {
        
        let pawn   : [Int] = [9, 10, 11]
        let knight : [Int] = [-21, -19, -8, -12, 19, 21, 8, 12]
        let bishop : [Int] = [-9, 9, -11, 11]
        let rook   : [Int] = [-10, 10, -1, 1]
        let queen  : [Int] = [-9, 9, -11, 11, -10, 10, -1, 1]
        let king   : [Int] = [-9, 9, -11, 11, -10, 10, -1, 1]
    }
    
    func loadTestPosition (testPosition: Int) {
        
        var testGameRecord = MoveList()
        switch testPosition {
        case 1: // Basic checkmate. There should be no legal moves for black.
            testGameRecord.moves.append(Move(from: std2ind("e2"), to: std2ind("e4")))
            testGameRecord.moves.append(Move(from: std2ind("e7"), to: std2ind("e5")))
            testGameRecord.moves.append(Move(from: std2ind("f1"), to: std2ind("c4")))
            testGameRecord.moves.append(Move(from: std2ind("d7"), to: std2ind("d6")))
            testGameRecord.moves.append(Move(from: std2ind("d1"), to: std2ind("f3")))
            testGameRecord.moves.append(Move(from: std2ind("b8"), to: std2ind("c6")))
            testGameRecord.moves.append(Move(from: std2ind("f3"), to: std2ind("f7")))
        
        case 2: // En-passant. e5->f6 should appear as a legal move
            testGameRecord.moves.append(Move(from: std2ind("e2"), to: std2ind("e4")))
            testGameRecord.moves.append(Move(from: std2ind("d7"), to: std2ind("d5")))
            testGameRecord.moves.append(Move(from: std2ind("e4"), to: std2ind("e5")))
            testGameRecord.moves.append(Move(from: std2ind("f7"), to: std2ind("f5"), epSq: std2ind("f6")))
            
        case 3: // Castling. e1->c1 and e1->g1 should appear as legal moves for white
            testGameRecord.moves.append(Move(from: std2ind("e2"), to: std2ind("e4")))
            testGameRecord.moves.append(Move(from: std2ind("e7"), to: std2ind("e5")))
            testGameRecord.moves.append(Move(from: std2ind("f1"), to: std2ind("c4")))
            testGameRecord.moves.append(Move(from: std2ind("b8"), to: std2ind("c6")))
            testGameRecord.moves.append(Move(from: std2ind("g1"), to: std2ind("f3")))
            testGameRecord.moves.append(Move(from: std2ind("d7"), to: std2ind("d6")))
            testGameRecord.moves.append(Move(from: std2ind("d1"), to: std2ind("e2")))
            testGameRecord.moves.append(Move(from: std2ind("c8"), to: std2ind("f5")))
            testGameRecord.moves.append(Move(from: std2ind("b2"), to: std2ind("b3")))
            testGameRecord.moves.append(Move(from: std2ind("f8"), to: std2ind("e7")))
            testGameRecord.moves.append(Move(from: std2ind("c1"), to: std2ind("b2")))
            testGameRecord.moves.append(Move(from: std2ind("g8"), to: std2ind("f6")))
            testGameRecord.moves.append(Move(from: std2ind("b1"), to: std2ind("b3"))) // Both white castles available
            testGameRecord.moves.append(Move(from: std2ind("e8"), to: std2ind("d7"))) // Both black castles available
            
        case 4: // Check. There is only one possible move (e8->d8) left
            testGameRecord.moves.append(Move(from: std2ind("e2"), to: std2ind("e4")))
            testGameRecord.moves.append(Move(from: std2ind("e7"), to: std2ind("e5")))
            testGameRecord.moves.append(Move(from: std2ind("f1"), to: std2ind("c4")))
            testGameRecord.moves.append(Move(from: std2ind("f8"), to: std2ind("c5")))
            testGameRecord.moves.append(Move(from: std2ind("d1"), to: std2ind("f3")))
            testGameRecord.moves.append(Move(from: std2ind("d8"), to: std2ind("g5")))
            testGameRecord.moves.append(Move(from: std2ind("f3"), to: std2ind("f7")))
            
        default: break
        }
        
        initializeGameBoard(testGameRecord)
        
    }
    
}














