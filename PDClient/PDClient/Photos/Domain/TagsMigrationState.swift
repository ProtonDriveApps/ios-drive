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

public struct TagsMigrationState: Equatable {
    public let isFinished: Bool
    public let anchor: Anchor?

    public init(isFinished: Bool, anchor: Anchor?) {
        self.isFinished = isFinished
        self.anchor = anchor
    }

    public struct Anchor: Equatable {
        public let lastProcessedLinkID: String
        public let lastProcessedCaptureTime: Date
        public let lastMigrationTimestamp: Date
        public let lastClientUID: String?

        public init(lastProcessedLinkID: String, lastProcessedCaptureTime: Date, lastMigrationTimestamp: Date, lastClientUID: String?) {
            self.lastProcessedLinkID = lastProcessedLinkID
            self.lastProcessedCaptureTime = lastProcessedCaptureTime
            self.lastMigrationTimestamp = lastMigrationTimestamp
            self.lastClientUID = lastClientUID
        }
    }
}
