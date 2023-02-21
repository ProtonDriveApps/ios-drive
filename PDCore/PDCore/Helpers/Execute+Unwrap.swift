// Copyright (c) 2023 Proton AG
//
// This file is part of Proton Drive.
//
// Proton Drive is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Proton Drive is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Proton Drive. If not, see https://www.gnu.org/licenses/.

import Foundation

func executeAndUnwrap<T>(caller: StaticString = #function, action: (inout NSError?) -> T?) throws -> T {
    var error: NSError?
    let output = action(&error)
    guard error == nil else { throw error! }
    guard output != nil else {
        throw NSError(domain: "Expected honest \(T.self), but found nil instead. \nCaller: \(caller)", code: 1)
    }
    return output!
}

func execute<T>(caller: StaticString = #function, action: (inout NSError?) -> T) throws -> T {
    var error: NSError?
    let output = action(&error)
    guard error == nil else { throw error! }
    return output
}

func execute<T>(caller: StaticString = #function, action: () throws -> T?) throws -> T {
    let optional = try action()
    guard optional != nil else {
        throw NSError(domain: "Expected honest \(T.self), but found nil instead. \nCaller: \(caller)", code: 1)
    }
    return optional!
}

func unwrap<T>(caller: StaticString = #function, action: () -> T?) throws -> T {
    let optional = action()
    guard optional != nil else {
        throw NSError(domain: "Expected honest \(T.self), but found nil instead. \nCaller: \(caller)", code: 1)
    }
    return optional!
}

func unwrap<T>(caller: StaticString = #function, action: () throws -> T?) throws -> T {
    let optional = try action()
    guard optional != nil else {
        throw NSError(domain: "Expected honest \(T.self), but found nil instead. \nCaller: \(caller)", code: 1)
    }
    return optional!
}
