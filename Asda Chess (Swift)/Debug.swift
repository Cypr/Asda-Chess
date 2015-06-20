//
//  Debug.swift
//  Kingsmen Chess
//
//  Created by Jeremy on 5/13/15.
//  Copyright (c) 2015 Cypress Inc. All rights reserved.
//

import Foundation

private var DebugConstants =
   ["master": true,
    "default": true,
    "warnings": true,
    "errors": true,
    "display debug tags": false,
    "board": true,
    "piece information": true,
    "printPseudoLegalMoveList": true,
    "printLegalMoveList": true, 
    "computePseudoLegalMoveList": false,
    "printMoveList": true,
    "board init with fen string": true]

public func debugPrintln (var string: String) {
    debugPrintln(string, "default")
}

public func debugPrintln (var string: String, tag: String) {
    if DebugConstants["master"]! == false { return }
    
    if let display = DebugConstants[tag] {
        if display {
            if DebugConstants["display debug tags"]! { string = "\"\(tag)\": " + string}
            println(string)
        }
    } else {
        println("Unknown debug tag \"\(tag)\"")
    }
}