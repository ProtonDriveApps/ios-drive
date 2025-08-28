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

import PDCore

/// Keeps track of enumerations in progress and reports their status using an instance of `SyncStorageManager`.
public protocol EnumerationObserverProtocol {
    var items: ItemEnumerationObserver { get }
    var changes: ChangeEnumerationObserver { get }
}

public class EnumerationObserver: EnumerationObserverProtocol {

#if DEBUG
    /// How many times has this been instantiated.
    private static var instanceCounter = 0
#endif

    public let items: ItemEnumerationObserver
    public let changes: ChangeEnumerationObserver

    public init(syncStorage: SyncStorageManager) {
#if DEBUG
        Log.trace(Self.instanceCounter.description)
#endif
        self.items = ItemEnumerationObserver(syncStorage: syncStorage)
        self.changes = ChangeEnumerationObserver(syncStorage: syncStorage)

#if DEBUG
        Self.instanceCounter += 1
#endif
    }

    deinit {
        Log.trace()
    }
}
