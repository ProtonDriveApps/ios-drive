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

import FileProvider
import PDCore
import PDLocalization

public class ChangeEnumerationObserver: BaseEnumerationObserver, NSFileProviderChangeObserver {
    public static let enumerationSyncItemIdentifier = "enumerateChanges"
    private let enumerationSyncItemName = Localization.detecting_remote_changes

    public func didStartEnumeratingChanges(name: String) {
        Log.trace("name: \(name)")

        let item = ReportableSyncItem(
            id: Self.enumerationSyncItemIdentifier,
            modificationTime: Date.now,
            filename: enumerationSyncItemName,
            location: nil,
            mimeType: nil,
            fileSize: nil,
            operation: .enumerateChanges,
            state: .inProgress,
            progress: 0)
        syncStorage.upsert(item)
    }

    public func didUpdate(_ updatedItems: [any NSFileProviderItemProtocol]) {
        Log.trace("\(updatedItems.count) items")
    }

    public func didDeleteItems(withIdentifiers deletedItemIdentifiers: [NSFileProviderItemIdentifier]) {
        Log.trace("\(deletedItemIdentifiers.count) items")
    }

    public func finishEnumeratingChanges(upTo anchor: NSFileProviderSyncAnchor, moreComing: Bool) {
        Log.trace("(more coming? \(moreComing))")
        if !moreComing {
            self.didFinishEnumeratingChanges(name: "", error: nil)
        }
    }

    public func finishEnumeratingWithError(_ error: any Error) {
        Log.trace("error: \(error.localizedDescription)")
        self.didFinishEnumeratingChanges(name: "", error: error)
    }

    private func didFinishEnumeratingChanges(name: String, error: Error?) {
        Log.trace("name: \(name), error: \(error?.localizedDescription ?? "n/a")")
        
        let item = ReportableSyncItem(
            id: Self.enumerationSyncItemIdentifier,
            modificationTime: Date.now,
            filename: enumerationSyncItemName,
            location: nil,
            mimeType: nil,
            fileSize: nil,
            operation: .enumerateChanges,
            state: error == nil ? .finished : .errored,
            progress: error == nil ? 100 : 0,
            errorDescription: error?.localizedDescription)

        syncStorage.upsert(item)
    }

    deinit {
        Log.trace()
    }
}
