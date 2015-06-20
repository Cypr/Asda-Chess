//
//  GameTreeNode.swift
//  Kingsmen Chess
//
//  Created by Jeremy on 5/25/15.
//  Copyright (c) 2015 Cypress Inc. All rights reserved.
//

import Foundation

class GameTreeNode {
    //var gameRecord = MoveList()
    var legalMoves : MoveList?
    var pseudoLegalMoves : MoveList?
    var opponentsPseudoLegalMoves : MoveList?
    var bestMove : Move?
    var ply = Int() // { return gameRecord.moves.count }
    
    var check : Bool?
    var evalScore: Int? // The final evaluation score for this board position
    var materialScore: Int? // The combined material score of black and white  (positive material score means white has a material advantage, a negative score the opposite)
    var positionScore: Int? // The combined position score of black and white
    
    var nodes = Dictionary<Move, GameTreeNode>()
    
    init(ply: Int) {
        self.ply = ply
    }
    
    func printNode() {
        debugPrintln("GameTreeNode", "GameTreeNode")
        debugPrintln("\nCurrent ply: \(ply)", "GameTreeNode")
        debugPrintln("\nlegalMoves (\(legalMoves?.moves.count) moves) ", "GameTreeNode")
        if bestMove != nil { debugPrintln("\nbestMove: \(bestMove!.from) to \(bestMove!.to)") }
    }
    
    func addLeafNode(move: Move) {
        nodes[move] = GameTreeNode(ply: self.ply+1)
    }
    
    //func getNode(board: Board) -> GameTreeNode? {
    //    return getNode(board.gameRecord)
    //}
    
    func getNode(gameRecord: MoveList) -> GameTreeNode? {
        if gameRecord.moves.count == ply {
            return self
        } else if let node = nodes[gameRecord.moves[self.ply]] {
            return node.getNode(gameRecord)
        } else {
            return nil
        }
    }
    
    func setNode(board: Board) {
        // Warning: This function will request ALL the node components from the board, which may result in the board having to compute extraneous information (opponentsPseudoLegalMoves, etc.)
        pseudoLegalMoves = board.getPseudoLegalMoveList()
        legalMoves = board.getLegalMoveList()
        opponentsPseudoLegalMoves = board.getPseudoLegalMoveList()
        
        bestMove = board.bestMove
        check = board.check
        evalScore = board.evalScore
        materialScore = board.materialScore
        positionScore = board.positionScore
    }
    
    func setNode(pseudoLegalMoves: MoveList?, legalMoves: MoveList?, opponentsPseudoLegalMoves: MoveList?, bestMove: Move?, check: Bool?, evalScore: Int?, materialScore: Int?, positionScore: Int?) {
        
        self.pseudoLegalMoves = pseudoLegalMoves
        self.legalMoves = legalMoves
        self.opponentsPseudoLegalMoves = opponentsPseudoLegalMoves
        self.bestMove = bestMove
        self.check = check
        self.evalScore = evalScore
        self.materialScore = materialScore
        self.positionScore = positionScore
    }
}








