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
@preconcurrency import PDCore
import ProtonDriveSDK

public enum NodeBatchOperation: Sendable {
    case trash
    case restore
    case delete
}

public enum NodeOperationStreamEvent: Sendable {
    case nodeResults(results: [NodeResult], affectedIdentifiers: [AnyVolumeIdentifier])
    case completed(error: Error?)
}

extension AsyncThrowingStream where Element == NodeOperationStreamEvent {
    public func collectCompletion() async throws -> (affectedIdentifiers: [AnyVolumeIdentifier], error: Error?) {
        var affectedIdentifiers: [AnyVolumeIdentifier] = []
        var error: Error?
        for try await event in self {
            switch event {
            case .nodeResults(_, let batchAffectedIdentifiers):
                affectedIdentifiers.append(contentsOf: batchAffectedIdentifiers)
            case .completed(let completionError):
                error = completionError
            }
        }
        return (affectedIdentifiers, error)
    }
}
