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

protocol PhotosStorageViewDataFactory {
    func makeData(state: QuotaState, progress: PhotosBackupProgress?) -> PhotosStorageViewData
}

final class LocalizedPhotosStorageViewDataFactory: PhotosStorageViewDataFactory {
    private let numberFormatter: NumberFormatterResource

    init(numberFormatter: NumberFormatterResource) {
        self.numberFormatter = numberFormatter
    }

    func makeData(state: QuotaState, progress: PhotosBackupProgress?) -> PhotosStorageViewData {
        switch state {
        case .fiftyPercentFull:
            return PhotosStorageViewData(
                severance: .info,
                title: "Your storage is **50%** full",
                items: nil,
                text: nil,
                storageButton: "Get storage",
                closeButton: "Not now"
            )
        case .eightyPercentFull:
            return PhotosStorageViewData(
                severance: .warning,
                title: "Your storage is more than **80%** full",
                items: nil,
                text: nil,
                storageButton: "Get storage",
                closeButton: "Not now"
            )
        case .full:
            return PhotosStorageViewData(
                severance: .error,
                title: "Storage full",
                items: makeItems(from: progress),
                text: "To continue the process you need to upgrade your plan.",
                storageButton: "Get more storage",
                closeButton: nil
            )
        }
    }

    private func makeItems(from progress: PhotosBackupProgress?) -> String? {
        if let count = progress?.inProgress {
            let number = numberFormatter.format(count)
            let items = count == 1 ? "item" : "items"
            return "**\(number)** \(items) left"
        } else {
            return nil
        }
    }
}
