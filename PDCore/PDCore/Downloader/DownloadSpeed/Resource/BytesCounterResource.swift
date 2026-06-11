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

public protocol BytesCounterResource {
    func add(bytes: Int)
    func getBytesCount() -> Int
    func reset()
}

public final class ThreadSafeBytesCounterResource: BytesCounterResource {
    @ThreadSafe private var totalCount: Int = 0

    public init() {}

    public func add(bytes: Int) {
        Log.debug("Adding bytes: \(bytes)", domain: .downloader)
        totalCount += bytes
    }

    public func reset() {
        Log.debug("Resetting", domain: .downloader)
        totalCount = 0
    }

    public func getBytesCount() -> Int {
        Log.debug("Total bytes: \(totalCount)", domain: .downloader)
        return totalCount
    }
}
