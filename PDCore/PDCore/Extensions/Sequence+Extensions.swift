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

public extension Sequence {
    func asyncMap<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
        var values = [T]()
        for element in self {
            try await values.append(transform(element))
        }
        return values
    }

    /// async version of `forEach`
    func forEach(_ operation: (Element) async throws -> Void) async rethrows {
        try await asyncForEach(operation)
    }
    
    func asyncForEach(_ operation: (Element) async throws -> Void) async rethrows {
        for element in self {
            try await operation(element)
        }
    }

    func parallelMap<T>(_ transform: @escaping (Element) async throws -> T) async rethrows -> [T] {
        return try await withThrowingTaskGroup(of: T.self) { taskGroup in
            for element in self {
                taskGroup.addTask { try await transform(element) }
            }
            return try await taskGroup.reduce([], { $0 + [$1] })
        }
    }
    
    func parallelForEach(_ transform: @escaping (Element) async throws -> Void) async rethrows {
        _ = try await parallelMap(transform)
    }

    /// Async version of `flatMap`
    /// Cannot be called just `flatMap`, the compiler gets confused
    func asyncFlatMap<T>(_ transform: (Element) async throws -> [T]) async rethrows -> [T] {
        var values = [T]()
        for element in self {
            try await values += transform(element)
        }
        return values
    }

    /// Async version of `compactMap`
    /// Cannot be called just `compactMap`, the compiler gets confused
    func asyncCompactMap<T>(_ transform: (Element) async throws -> T?) async rethrows -> [T] {
        var values = [T]()
        for element in self {
            if let value = try await transform(element) {
                values.append(value)
            }
        }
        return values
    }

    /// async version of `filter`
    func filter(_ operation: (Element) async throws -> Bool) async rethrows -> [Element] {
        var values = [Element]()
        for element in self {
            if try await operation(element) {
                values.append(element)
            }
        }
        return values
    }
}
