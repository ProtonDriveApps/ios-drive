// Copyright (c) 2024 Proton AG
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

public func abortIfCancelled(progress: Progress?) throws {
    if Task.isCancelled || progress?.isCancelled == true {
        throw CocoaError(.userCancelled)
    }
}

public func performIfNotCancelled<T>(progress: Progress?, _ work: () -> T) throws -> T {
    try abortIfCancelled(progress: progress)
    return work()
}

public func performIfNotCancelled<T>(progress: Progress?, _ work: () throws -> T) throws -> T {
    try abortIfCancelled(progress: progress)
    return try work()
}

public func performIfNotCancelled<T>(progress: Progress?, _ work: () async -> T) async throws -> T {
    try abortIfCancelled(progress: progress)
    return await work()
}

public func performIfNotCancelled<T>(progress: Progress?, _ work: () async throws -> T) async throws -> T {
    try abortIfCancelled(progress: progress)
    return try await work()
}

public func throwIfNotCancelled(progress: Progress?, error: @autoclosure () -> Swift.Error) throws -> Never {
    try abortIfCancelled(progress: progress)
    throw error()
}
