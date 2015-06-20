//
//  Adrastos.swift
//  Kingsmen Chess
//
//  Created by Jeremy on 5/25/15.
//  Copyright (c) 2015 Cypress Inc. All rights reserved.
//

import Foundation

class Adrastos {
    
    var maxDepth = 2
    
    init() {}
    
    convenience init(maxDepth: Int) {
        self.init()
        self.maxDepth = maxDepth
    }
    
    struct PieceValues {
        // Taken from https://chessprogramming.wikispaces.com/Simplified+evaluation+function
        static let pawn = 100
        static let knight = 320
        static let bishop = 330
        static let rook = 500
        static let queen = 900
        static let king = 20000
    }
    
    struct SquareTables {
        // Taken from https://chessprogramming.wikispaces.com/Simplified+evaluation+function
        
        static let whitePawn =
           [0,  0,  0,  0,  0,  0,  0,  0,
            50, 50, 50, 50, 50, 50, 50, 50,
            10, 10, 20, 30, 30, 20, 10, 10,
            5,  5, 10, 25, 25, 10,  5,  5,
            0,  0,  0, 20, 20,  0,  0,  0,
            5, -5,-10,  0,  0,-10, -5,  5,
            5, 10, 10,-20,-20, 10, 10,  5,
            0,  0,  0,  0,  0,  0,  0,  0]
        
        static let blackPawn = whitePawn.reverse()
        
        static let whiteKnight =
           [-50,-40,-30,-30,-30,-30,-40,-50,
            -40,-20,  0,  0,  0,  0,-20,-40,
            -30,  0, 10, 15, 15, 10,  0,-30,
            -30,  5, 15, 20, 20, 15,  5,-30,
            -30,  0, 15, 20, 20, 15,  0,-30,
            -30,  5, 10, 15, 15, 10,  5,-30,
            -40,-20,  0,  5,  5,  0,-20,-40,
            -50,-40,-30,-30,-30,-30,-40,-50]
        
        static let blackKnight = whiteKnight.reverse()
        
        static let whiteBishop =
           [-20,-10,-10,-10,-10,-10,-10,-20,
            -10,  0,  0,  0,  0,  0,  0,-10,
            -10,  0,  5, 10, 10,  5,  0,-10,
            -10,  5,  5, 10, 10,  5,  5,-10,
            -10,  0, 10, 10, 10, 10,  0,-10,
            -10, 10, 10, 10, 10, 10, 10,-10,
            -10,  5,  0,  0,  0,  0,  5,-10,
            -20,-10,-10,-10,-10,-10,-10,-20]
        
        static let blackBishop = whiteBishop.reverse()
        
        static let whiteRook =
           [0,  0,  0,  0,  0,  0,  0,  0,
            5, 10, 10, 10, 10, 10, 10,  5,
            -5,  0,  0,  0,  0,  0,  0, -5,
            -5,  0,  0,  0,  0,  0,  0, -5,
            -5,  0,  0,  0,  0,  0,  0, -5,
            -5,  0,  0,  0,  0,  0,  0, -5,
            -5,  0,  0,  0,  0,  0,  0, -5,
            0,  0,  0,  5,  5,  0,  0,  0]
        
        static let blackRook = whiteRook.reverse()
        
        static let whiteQueen =
           [-20,-10,-10, -5, -5,-10,-10,-20,
            -10,  0,  0,  0,  0,  0,  0,-10,
            -10,  0,  5,  5,  5,  5,  0,-10,
            -5,  0,  5,  5,  5,  5,  0, -5,
             0,  0,  5,  5,  5,  5,  0, -5,
            -10,  5,  5,  5,  5,  5,  0,-10,
            -10,  0,  5,  0,  0,  0,  0,-10,
            -20,-10,-10, -5, -5,-10,-10,-20]
        
        static let blackQueen = whiteQueen.reverse()
        
        static let whiteKingMid =
           [-30,-40,-40,-50,-50,-40,-40,-30,
            -30,-40,-40,-50,-50,-40,-40,-30,
            -30,-40,-40,-50,-50,-40,-40,-30,
            -30,-40,-40,-50,-50,-40,-40,-30,
            -20,-30,-30,-40,-40,-30,-30,-20,
            -10,-20,-20,-20,-20,-20,-20,-10,
             20, 20,  0,  0,  0,  0, 20, 20,
             20, 30, 10,  0,  0, 10, 30, 20]
        
        static let blackKingMid = whiteKingMid.reverse()
        
        static let whiteKingEnd =
           [-50,-40,-30,-20,-20,-30,-40,-50,
            -30,-20,-10,  0,  0,-10,-20,-30,
            -30,-10, 20, 30, 30, 20,-10,-30,
            -30,-10, 30, 40, 40, 30,-10,-30,
            -30,-10, 30, 40, 40, 30,-10,-30,
            -30,-10, 20, 30, 30, 20,-10,-30,
            -30,-30,  0,  0,  0,  0,-30,-30,
            -50,-30,-30,-30,-30,-30,-30,-50]
        
        static let blackKingEnd = whiteKingEnd.reverse()
    }
    
    func lazyEval(board: Board) -> Int {
        // We evaluate the board on two parts: (1) the material score, and (2) the position score.
                
        // Get the material score
        setMaterialScore(board)
                
        // Compute the positional score
        setPositionScore(board)
        
        // Combine the individual scores to get the board evaluation
        board.evalScore = board.materialScore! + board.positionScore!
        
        return board.evalScore!
    }
    
    func staticEvalMoveList(board: Board, moveList: MoveList) -> (MoveList) {
        
        //var testBoard = Board(gameRecord: board.gameRecord, adrastos: self)
        var testBoard = Board(board: board)
        
        for move in moveList.moves {
            if move.evalScore==nil {
                testBoard.makeMove(move)
                move.evalScore = lazyEval(testBoard)
                //testBoard.undoMove()
                testBoard.undoMove(move)
            }
        }
        
        return (moveList)
    }
    
    func selectMove(board: Board) -> Move? {
        // This function evaluates the board (adding the evaluationScores to the legalMoveList) and returns the best move 
        
        var selectedMove: Move? = nil
        var legalMoves: MoveList
        
        // Use alpha-beta to select the best move
        switch 2 {
        case 1:
            (legalMoves, selectedMove) = minMax(board, depth: maxDepth)
            
            // Copy over the evaluated legal moves and the selected move to the board
            board.setLegalMoveList(legalMoves)
            board.bestMove = selectedMove
            
        case 2:
            var alpha = GlobalParameters.numbers.negInf
            var beta  = GlobalParameters.numbers.posInf
            
            board.bestMove = alphaBeta(board, move: nil, depth: maxDepth, alpha: alpha, beta: beta)
            
            
        default: break
        }
        
        return board.bestMove
    }
    
    func setBestMove(board: Board) {
        board.bestMove = selectMove(board)
    }
    
    func initBoardForAI(board: Board) {
        // This function initializes a board to be used with Adrastos
        
        // Set the piece values on the board
        setPieceValues(board)
    }
    
    func setPieceValues(board: Board) {
        
        board.pieceValues["pawn"]   = PieceValues.pawn
        board.pieceValues["knight"] = PieceValues.knight
        board.pieceValues["bishop"] = PieceValues.bishop
        board.pieceValues["rook"]   = PieceValues.rook
        board.pieceValues["queen"]  = PieceValues.queen
        board.pieceValues["king"]   = PieceValues.king
        
        for piece in board.pieces {
            switch piece.type {
                case "pawn":   piece.value = PieceValues.pawn
                case "knight": piece.value = PieceValues.knight
                case "bishop": piece.value = PieceValues.bishop
                case "rook":   piece.value = PieceValues.rook
                case "queen":  piece.value = PieceValues.queen
                case "king":   piece.value = PieceValues.king
                default: break
            }
        }
    }
    
    func setPositionScore(board: Board) -> Int {
        if board.positionScore == nil { computePositionScore(board) }
        
        return board.positionScore!
    }
    
    private func computePositionScore(board: Board) -> Int{
        board.positionScore = 0
        
        //println("board position score is now 0")
        for piece in board.pieces {
            switch (piece.intType) {
            case 1: if piece.location != 0 {board.positionScore! += SquareTables.whitePawn[board.oneTwenty2sixtyFour(piece.location)]}
            case 2: if piece.location != 0 {board.positionScore! += SquareTables.whiteKnight[board.oneTwenty2sixtyFour(piece.location)]}
            case 3: if piece.location != 0 {board.positionScore! += SquareTables.whiteBishop[board.oneTwenty2sixtyFour(piece.location)]}
            case 4: if piece.location != 0 {board.positionScore! += SquareTables.whiteRook[board.oneTwenty2sixtyFour(piece.location)]}
            case 5: if piece.location != 0 {board.positionScore! += SquareTables.whiteQueen[board.oneTwenty2sixtyFour(piece.location)]}
            case 6: if piece.location != 0 {if board.gamePhase=="Mid" {board.positionScore! += SquareTables.whiteKingMid[board.oneTwenty2sixtyFour(piece.location)] }
                                            else if board.gamePhase=="End" {board.positionScore! += SquareTables.whiteKingEnd[board.oneTwenty2sixtyFour(piece.location)]} }
                
            case -1: if piece.location != 0 {board.positionScore! -= SquareTables.blackPawn[board.oneTwenty2sixtyFour(piece.location)]}
            case -2: if piece.location != 0 {board.positionScore! -= SquareTables.blackKnight[board.oneTwenty2sixtyFour(piece.location)]}
            case -3: if piece.location != 0 {board.positionScore! -= SquareTables.blackBishop[board.oneTwenty2sixtyFour(piece.location)]}
            case -4: if piece.location != 0 {board.positionScore! -= SquareTables.blackRook[board.oneTwenty2sixtyFour(piece.location)]}
            case -5: if piece.location != 0 {board.positionScore! -= SquareTables.blackQueen[board.oneTwenty2sixtyFour(piece.location)]}
            case -6: if piece.location != 0 {if board.gamePhase=="Mid" {board.positionScore! -= SquareTables.blackKingMid[board.oneTwenty2sixtyFour(piece.location)] }
                                             else if board.gamePhase=="End" {board.positionScore! -= SquareTables.blackKingEnd[board.oneTwenty2sixtyFour(piece.location)]} }
                
            default: break
            }
            
            //if piece.location != 0 {
            //    println("board position score is now \(board.positionScore!) after adding piece \(piece.owner) \(piece.type) at \(piece.location) (\(board.ind2std(piece.location)))")
            //}
        }
        
        return board.positionScore!
    }
    
    func setMaterialScore(board: Board) -> Int {
        if board.materialScore == nil { computeMaterialScore(board) }
        
        return board.materialScore!
    }
    
    private func computeMaterialScore(board: Board) {
        var material = 0
        for piece in board.pieces {
            if piece.location != 0 {
                material += piece.intColor * piece.value!
            }
        }
        board.materialScore = material
    }
    
    func minMax(board: Board, depth: Int) -> (MoveList, Move?) {
        // Evaluates all the moves in the root node, returning them with their score; also returns the highest scored move.
        
        // Score each move at the root node
        var legalMoves = MoveList()
        var legalMove: Move
        for move in board.getLegalMoveList().moves {
            board.makeMove(move)
            
            legalMove = minMaxHelper(board, move: move, depth: depth-1)!
            legalMoves.moves.append(legalMove)
            //board.printMove(legalMove)
            
            board.undoMove(move)
        }
        
        // Go through the scored moves and select the best one
        var bestScore = board.toMoveInt * GlobalParameters.numbers.negInf
        var selectedMove: Move?
        for move in legalMoves.moves {
            //board.printMove(move)
            switch board.toMove {
                case "white":
                    if move.evalScore! > bestScore {
                        selectedMove = move
                        bestScore = move.evalScore!
                    }
                case "black":
                    if move.evalScore! < bestScore {
                        selectedMove = move
                        bestScore = move.evalScore!
                    }
                
                default: break
            }
        }
        
        return (legalMoves, selectedMove)
    }
    
    private func minMaxHelper(board: Board, move: Move, depth: Int) -> (Move?) {
        // The actual alphaBeta implementation.
        
        if depth==0 {
            move.evalScore = lazyEval(board)
            return move
        }
        if board.getLegalMoveList().moves.count == 0 { // we should really test for checkmate, etc. here
            move.evalScore = lazyEval(board)
            return (move)
        }
        
        // Sort getLegalMoveList here
        
        var bestScore: Int = GlobalParameters.numbers.negInf * board.toMoveInt
        var selectedMove: Move?
        var potentialMove: Move?
        
        for move in board.getLegalMoveList().moves {
            board.makeMove(move)
            potentialMove = minMaxHelper(board, move: move, depth: depth-1)
            board.undoMove(move)
            
            /*
            if potentialMove?.evalScore == nil {
                debugPrintln("Unevaluatable move!")
            } else {
                println("Potential Score: \(potentialMove!.evalScore!), Best Score: \(bestScore)")
            }
            */
            
            switch board.toMove {
                case "white":
                    if potentialMove!.evalScore! > bestScore {
                        selectedMove = potentialMove
                        bestScore = potentialMove!.evalScore!
                    }
                case "black":
                    if potentialMove!.evalScore! < bestScore {
                        selectedMove = potentialMove
                        bestScore = potentialMove!.evalScore!
                    }
            
                default: break
            }
        }
        //println("Selecting the following move, which was given a score of \(bestScore)")
        //if selectedMove != nil {board.printMove(selectedMove!)}
        //else {println("move was nil!")}
        
        move.evalScore = bestScore
        return move
    }
    
    func alphaBeta(board: Board, move: Move?, depth: Int, var alpha: Int, var beta: Int) -> Move? {
        // A reimplementation of the alpha-beta routine as listed in the pseudo-code on wikipedia. Note that we assume the depth is at least 1 or we will crash.
        
        // If we're at the terminal depth we return
        if depth==0 {
            move!.evalScore = lazyEval(board)
            return move
        }
        
        // We also return if there are no more moves to be made
        if board.getLegalMoveList().moves.count == 0 { // we should really test for checkmate, etc. here
            if move != nil { move!.evalScore = lazyEval(board) }
            return move
        }
        
        // Sort legal move list. For now we do a static eval on every move and sort highest to lowest.
        board.setLegalMoveList(staticEvalMoveList(board, moveList: board.getLegalMoveList()))
        board.sortLegalMoveList()
        //board.printMoveList(board.getLegalMoveList())
        
        // Recurse to find the best move 
        var selectedMove: Move?, potentialMove: Move?
        switch board.toMove {
            case "white":
                var v = GlobalParameters.numbers.negInf
                for move in board.getLegalMoveList().moves {
                    board.makeMove(move)
                    
                    potentialMove = alphaBeta(board, move: move, depth: depth-1, alpha: alpha, beta: beta)
                    //board.printMove(potentialMove!)
                    if potentialMove!.evalScore! > v {
                        selectedMove = potentialMove
                        v = potentialMove!.evalScore!
                        alpha = max(alpha, v)
                    }
                    
                    board.undoMove(move)
                    
                    if beta <= alpha { break }
                }
            
            case "black":
                var v = GlobalParameters.numbers.posInf
                for move in board.getLegalMoveList().moves {
                    board.makeMove(move)
                    
                    potentialMove = alphaBeta(board, move: move, depth: depth-1, alpha: alpha, beta: beta)
                    if potentialMove!.evalScore! < v {
                        selectedMove = potentialMove
                        v = potentialMove!.evalScore!
                        beta = min(beta, v)
                    }
                    
                    board.undoMove(move)
                    
                    if beta <= alpha { break }
                }
            
            default: debugPrintln("Adrastos.alphaBeta() Ruh Roh")
        }
        
        //return selectedMove
        if move == nil { // If we are in the first level then pass back the best legal move we found
            return selectedMove
        } else { // if we are in the deeper levels we are just keeping track of the value of tried moves
            move!.evalScore = selectedMove!.evalScore
            return move
        }
    }
}

















