// Copyright (c) 2025 Proton AG
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

public final class MockTagsMigrationAPIClient: TagsMigrationAPIClient {
    public var simulatedState: TagsMigrationState

    public init(
        isFinished: Bool = false,
        anchor: TagsMigrationState.Anchor? = TagsMigrationState.Anchor(
            lastProcessedLinkID: "mock-link-id",
            lastProcessedCaptureTime: Date(timeIntervalSince1970: 1_680_000_000),
            lastMigrationTimestamp: Date(timeIntervalSince1970: 1_680_000_300),
            lastClientUID: "mock-client-uid"
        )
    ) {
        self.simulatedState = TagsMigrationState(isFinished: isFinished, anchor: anchor)
    }

    public func getTagsMigrationState(volumeID: String) async throws -> TagsMigrationState {
        return simulatedState
    }

    public func setTagsMigrationState(volumeID: String, request: TagsMigrationStateRequest) async throws {
        simulatedState = TagsMigrationState(
            isFinished: request.finished,
            anchor: request.anchor.map {
                TagsMigrationState.Anchor(
                    lastProcessedLinkID: $0.lastProcessedLinkID,
                    lastProcessedCaptureTime: Date(timeIntervalSince1970: TimeInterval($0.lastProcessedCaptureTime)),
                    lastMigrationTimestamp: Date(timeIntervalSince1970: TimeInterval($0.currentTimestamp)),
                    lastClientUID: $0.clientUID
                )
            }
        )
    }
}
