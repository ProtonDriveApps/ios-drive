//
//  File.swift
//  
//
//  Created by Daniel Chick on 11/2/22.
//

import Foundation

class Printer {
    static var showPrintStatements = false
    static func printMessage(_ items: Any..., separator: String = " ", terminator: String = "\n") {
        if showPrintStatements {
            print(items, separator: separator, terminator: terminator)
        }
    }
}
