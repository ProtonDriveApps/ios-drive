// Copyright (c) 2026 Proton AG
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
import ProtonCoreUtilities

public extension Atomic where A == Bool {
    /// Sets the `value` to a new value, returning whether the updated value is different to the previous one.
    ///
    /// You can use this in situations where you want to ensure something is done only once in a thread safe way:
    /// ```
    /// var needToDoSomethingOnlyOnce = Atomic<Bool>(false)
    /// ...
    /// if needToDoSomethingOnlyOnce.changeValue(to: true) {
    ///     doSomething()
    /// }
    /// ```
    ///
    /// Do not be tempted by this pattern instead, as there is a race condition between checking `value` and mutating it.
    /// ```
    /// var needToDoSomethingOnlyOnce = Atomic<Bool>(false)
    /// if !needToDoSomethingOnlyOnce.value {
    ///     needToDoSomethingOnlyOnce.mutate { $0.toggle() }
    ///     doSomething()
    /// }
    /// ```
    /// (This is similar in concept to the "Compare and Swap" pattern in atomics programming.)
    ///
    /// - Note: This should probably belongs Atomic.swift, but that would entail updating Proton Core, so I avoided it for now.
    ///
    /// - Parameter newValue: What `value` should be set to.
    /// - Returns: `true` if  `newValue` was different to the existing `value` and `value` was changed.
    ///            `false` if `value` was already the same as `newValue` and was not changed.
    public func changeValue(to newValue: A) -> Bool {
        var didChange = false
        mutate {
            guard $0 != newValue else { return }
            $0 = newValue
            didChange = true
        }
        return didChange
    }
}

public extension Atomic where A: AdditiveArithmetic, A: ExpressibleByIntegerLiteral {
    func increment() -> A {
        var returnValue: A = .zero
        mutate { value in
            value += 1
            returnValue = value
        }
        return returnValue
    }
    
    func decrement() -> A {
        var returnValue: A = .zero
        mutate { value in
            value -= 1
            returnValue = value
        }
        return returnValue
    }
}
