//
//  File.swift
//
//
//  Created by Fredrik Strand Oseberg on 13/05/2021.
//

import Foundation

public func unwrap<T>(_ any: T) -> Any {
    let mirror = Mirror(reflecting: any)
    guard mirror.displayStyle == .optional, let first = mirror.children.first else {
        return any
    }
    return first.value
}
