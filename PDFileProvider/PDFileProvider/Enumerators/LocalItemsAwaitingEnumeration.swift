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

import FileProvider
import ProtonCoreUtilities
import PDCore

public class LocalItemsAwaitingEnumeration {
    private static let pageSize = 150

    private var items: Atomic<[NSFileProviderItemIdentifier]> = .init([])

    public init() {}

    public func push(_ itemIdentifiers: [NSFileProviderItemIdentifier]) {
        Log.trace("\(itemIdentifiers.count) items pushed", domain: .offlineAvailable)
        items.mutate { $0.append(contentsOf: itemIdentifiers) }
    }

    public func popNextPage() -> [NSFileProviderItemIdentifier] {
        let count = min(Self.pageSize, items.value.count)
        let identifiers = Array(items.value.prefix(count))
        items.mutate { $0.removeFirst(count) }
        return identifiers
    }
}
