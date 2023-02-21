//
//  Atomic.swift
//  ProtonCore-Utilities - Created on 25.04.22.
//
//  Copyright (c) 2022 Proton Technologies AG
//
//  This file is part of Proton Technologies AG and ProtonCore.
//
//  ProtonCore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonCore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonCore. If not, see https://www.gnu.org/licenses/.
//

// Inspired by https://www.objc.io/blog/2018/12/18/atomic-variables/ article

public final class Atomic<A> {
    
    private let serialAccessQueue = DispatchQueue(label: "ch.proton.atomic_queue")
    private var internalValue: A
    
    public init(_ value: A) {
        self.internalValue = value
    }

    public var value: A {
        serialAccessQueue.sync {
            self.internalValue
        }
    }
    
    public func fetch<T>(_ fetchingKeyPath: KeyPath<A, T>) -> T {
        serialAccessQueue.sync {
            self.internalValue[keyPath: fetchingKeyPath]
        }
    }

    public func mutate(_ transform: (inout A) -> Void) {
        serialAccessQueue.sync {
            transform(&self.internalValue)
        }
    }
    
    public func transform<T>(_ transform: (A) -> T) -> T {
        serialAccessQueue.sync {
            transform(self.internalValue)
        }
    }
}
