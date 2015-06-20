//
//  Piece.swift
//  Kingsmen Chess
//
//  Created by Jeremy on 5/13/15.
//  Copyright (c) 2015 Cypress Inc. All rights reserved.
//

import Foundation

func ==(lhs: Piece, rhs: Piece) -> Bool {
    return lhs.hashValue == rhs.hashValue
}

class Piece: Hashable {
    var type      : String // pawn, knight, bishop, rook, queen, king
    var owner     : String // white, black
    var intType   : Int { return getIntType() } // the Int values associated with the type
    var intColor  : Int { return (owner=="white" ? 1 : -1) }
    var value     : Int?   // the base value of a piece for material evaluation purposes
    var location  : Int    // 120-byte board representation location (0-119)
    var moveCounter : Int!
    var everMoved : Bool { if moveCounter==nil {return true} else { return moveCounter>0 } }  // has this piece ever moved
    var index     : Int    // each piece on the board receives a unique id (0-31)
    
    var hashValue: Int { return computeHash() }
    
    func computeHash() -> Int {
        return "\(type)\(owner)\(value)\(location)\(everMoved)\(index)".hashValue
    }
    
    init (type: String, location: Int, owner: String, index: Int) {
        
        self.type = type
        //self.value = GlobalParameters.Pieces.PieceValues[type]!
        self.location = location
        self.moveCounter = 0
        self.owner = owner
        self.index = index
    }
    
    private func getIntType() -> Int {
        switch type {
            case "pawn":   return intColor * 1
            case "knight": return intColor * 2
            case "bishop": return intColor * 3
            case "rook":   return intColor * 4
            case "queen":  return intColor * 5
            case "king":   return intColor * 6
            default: return 0
        }
    }
}


