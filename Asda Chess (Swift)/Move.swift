//
//  move.swift
//  Kingsmen Chess
//
//  Created by Jeremy on 5/11/15.
//  Copyright (c) 2015 Cypress Inc. All rights reserved.
//

import Foundation

func ==(lhs: Move, rhs: Move) -> Bool {
    return lhs.hashValue == rhs.hashValue
}

class Move: Hashable {
    var from : Int
    var to   : Int
    var fen  : String? // A special "legal" move is simply to set the board to a particular state via a fen string
    var rootBoard : Board? // Another special "legal" move is simply to set the board to a particular state directly from a stored root board. Doing so is faster than using the fen string (which must be converted into a board) but takes more memory; note that the rootBoard will be used if present, followed by the fen string if present, followed by the "normal" from-to move. 
    
    var fromId: Int? // The piece id's (0-31) of the pieces being moved (and captured if relevant).
    var toId: Int?   // Note that for the 'toId', in the case of an en-passant capture, the location of the toId piece will NOT be where the fromId piece is moving to (as it's moving to the empty square left behind by the double pawn push). I.e. if this move is an en-passant capture, 'to' will NOT equal pieces[toId].location, for all other cases they will be equal if present (note that during castling toId is not used, instead the castling variable is used)
    
    var pro  : String? // promotion piece; only relevant if the moving piece is a pawn moving to the final rank, in which case 'pro' is set to the promoted piece type ('knight', 'bishop', 'rook', 'queen')
    var epSq   : Int? // en passant square; only relevant if the moving piece is a pawn moving forward two spaces for its first move. If non-nil the current move leaves this square behind as a potential capture square. I.e. this square is the square that is being skipped by a double pawn push
    var epCap  : Int? // en pass capture; only relevant if we are actually capturing a piece through en-passant. In this case eqCap holds the board location of the piece we are capturing (not where we're moving)
    var castling : (kingId: Int, rookId: Int)? // whether or not the move is a castling move; technically this information is superfluous (as its the only possible way a king can move two spaces), nevertheless it saves us a check we'd have to do later
    
    // The following parameters are not necessarily expected to be filled, even if they apply.
    var check : Bool? // This move results in checking the opponent
    var evalScore : Int? // The evaluation score applied to this position. More positive values are better for white, more negative values are better for black
    
    // We need to create a hashValue for the Hashable protocol so we can be used as a key in a dictionary
    var hashValue: Int { return computeHash() }
    
    func computeHash() -> Int {
        return "\(from)\(to)\(pro)\(epSq)\(epCap)".hashValue
    }
    
    func getIds(pieces: [Piece]) {
        if fromId==nil {
            for piece in pieces {
                if piece.location == from {
                    fromId = piece.index
                    break
                }
            }
        }
        
        if toId==nil {
            if epCap == nil { // If this isn't an en-passant capture (which needs to be handled slightly differently), just go through the pieces and see if there's a piece at the square we're moving to
                for piece in pieces {
                    if piece.location == to {
                        toId = piece.index
                        break
                    }
                }
            } else { // If we're doing an en-passant capture the piece we're capturing is not actually on the square we're moving to
                for piece in pieces {
                    if piece.location == epCap {
                        toId = piece.index
                        break
                    }
                }
            }
        }
    }
    
    func getEpSq() -> Int? {
        // This function gets the epSq for this move. This would be simple except that if the move if a board state or fen string we have to do a little work. The purpose of this move is so that we can look at the gameRecord (which stores moves but not board states) and get the epSq for any ply, allowing us to undoMove without replaying the game.
        
        if rootBoard != nil {
            return rootBoard!.epSq
        }
        
        if fen != nil {
            var tempBoard = Board(fen: fen!)
            return tempBoard.epSq
        }
        
        return epSq
    }
    
    init(fen: String) {
        self.fen = fen
        
        // The following aren't used but need to be set
        from = 0
        to = 0
    }
    
    init(board: Board) {
        self.rootBoard = board
        
        // The following aren't used but need to be set
        from = 0
        to = 0
    }
    
    init(from: Int, to: Int) {
        self.from = from
        self.to = to
    }
    
    init(from: Int, to: Int, pro: String) {
        self.from = from
        self.to = to
        self.pro = pro
    }
    
    init(from: Int, to: Int, epSq: Int) {
        self.from = from
        self.to = to
        self.epSq = epSq
    }
    
    init(from: Int, to: Int, epCap: Int) {
        self.from = from
        self.to = to
        self.epCap = epCap
    }
    
    init(from: Int, to: Int, castling: (Int, Int)) {
        self.from = from
        self.to = to
        self.castling = castling
    }
    
    init(from: Int, to: Int, fromId: Int) {
        self.from = from
        self.to = to
        self.fromId = fromId
    }
    
    init(from: Int, to: Int, pro: String, fromId: Int) {
        self.from = from
        self.to = to
        self.pro = pro
        self.fromId = fromId
    }
    
    init(from: Int, to: Int, epSq: Int, fromId: Int) {
        self.from = from
        self.to = to
        self.epSq = epSq
        self.fromId = fromId
    }
    
    init(from: Int, to: Int, epCap: Int, fromId: Int) {
        self.from = from
        self.to = to
        self.epCap = epCap
        self.fromId = fromId
    }
    
    init(from: Int, to: Int, castling: (Int, Int), fromId: Int) {
        self.from = from
        self.to = to
        self.castling = castling
        self.fromId = fromId
    }
    
    
    
    
    
    
    
}