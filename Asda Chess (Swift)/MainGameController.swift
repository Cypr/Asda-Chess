//
//  MainGameController.swift
//  Kingsmen Chess
//
//  Created by Jeremy on 6/2/15.
//  Copyright (c) 2015 Cypress Inc. All rights reserved.
//

import UIKit

class MainGameController: UIViewController {
    
    var board = Board()
    var white = Adrastos(maxDepth: 4), black = Adrastos(maxDepth: 3)
    
    override func viewDidLoad() {
        white.initBoardForAI(board)
        
        // Conduct Perft Test
        //perftTest()
        
        // Test the new undoMove(move) funcionality
        //testUndoMove()
        
        // Play test game
        playTestGame()
    }
    
    func perftTest() {
        var pos1 = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
        var pos2 = "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq -"
        var pos3 = "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - -"
        var pos4 = "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1"
        var pos5 = "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8"
        var pos6 = "r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10"
        
        //board.perft(pos1, depth: 1) // 20
        //board.perft(pos1, depth: 2) // 400
        //board.perft(pos1, depth: 3) // desired total: 8902
        //board.perft(pos2, depth: 3) // desired total: 97862
        //board.perft(pos3, depth: 1)
        //board.perft(pos3, depth: 2)
        //board.perft(pos3, depth: 3) // desired total: 2812
        //board.perft(pos3, depth: 4)
        //board.perft(pos4, depth: 1)
        //board.perft(pos4, depth: 2)
        board.perft(pos4, depth: 3) // desired total: 9467
        //board.perft(pos5, depth: 3) // desired total: 53392
        //board.perft(pos6, depth: 3) // desired total: 89890
    }
    
    func playTestGame() {
        board.printBoard()
        
        for i in 1...100 {
            // Select move (also evaluates all the possible legal moves)
            switch board.toMove {
            case "white": white.selectMove(board)
            case "black": black.selectMove(board)
            default: break
            }
            
            // Print evaluated legal moves
            //board.printLegalMoveList()
            
            // Make the selected move
            if board.bestMove == nil {
                debugPrintln("Checkmate (or stalemate)! No available moves.")
                break
            } else {
                (board.toMove=="white") ? debugPrintln("White's move: ") : debugPrintln("Black's move: ")
                board.printMove(board.bestMove!)
                board.makeMove(board.bestMove!)
                //println("Number of moves: \(board.gameRecord.moves.count)")
            }
            
            // Print board
            board.printBoard()
        }
        board.printBoard()
        println("Number of moves: \(board.currentPly)")
    }
    
    func testUndoMove() {
        
        var boardUM1 = Board(fen: "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - -")
        var boardUM2 = Board(fen: "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - -")
        var sanityCheck: Bool {return (boardUM1 == boardUM2)}
        if !sanityCheck {(debugPrintln("We have a problem"))}
        
        boardUM1.printBoard()
        for move in boardUM1.getLegalMoveList().moves {
            boardUM1.printMove(move)
            
            boardUM1.makeMove(move)
            boardUM1.undoMove()
            boardUM2.makeMove(move)
            boardUM2.undoMove(move)
            
            if !sanityCheck {
                debugPrintln("undoMove():     \(boardUM1.fen)")
                boardUM1.printBoard()
                debugPrintln("undoMove(move): \(boardUM2.fen)")
                boardUM2.printBoard()
            } else {
                debugPrintln("Above move is ok.\n\n")
            }
        }
    }
    
    func drawBoard(board: Board) {
        
    }
    
    
}
