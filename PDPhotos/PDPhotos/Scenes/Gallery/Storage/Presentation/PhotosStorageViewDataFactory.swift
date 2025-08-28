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
import PDLocalization

protocol PhotosStorageViewDataFactory {
    func makeData(state: QuotaState, progress: PhotosBackupProgress?) -> PhotosStorageViewData
}

final class LocalizedPhotosStorageViewDataFactory: PhotosStorageViewDataFactory {

    func makeData(state: QuotaState, progress: PhotosBackupProgress?) -> PhotosStorageViewData {
        switch state {
        case .fiftyPercentFull:
            return PhotosStorageViewData(
                severance: .info,
                title: Localization.photo_storage_fifty_percent_title,
                items: nil,
                text: nil,
                storageButton: Localization.general_get_storage,
                closeButton: Localization.general_not_now,
                accessibilityIdentifier: "PhotosStorageViewData.FiftyPercentFullStorage"
            )
        case .eightyPercentFull:
            return PhotosStorageViewData(
                severance: .warning,
                title: Localization.photo_storage_eighty_percent_title,
                items: nil,
                text: nil,
                storageButton: Localization.general_get_storage,
                closeButton: Localization.general_not_now,
                accessibilityIdentifier: "PhotosStorageViewData.EightyPercentFullStorage"
            )
        case .full:
            return PhotosStorageViewData(
                severance: .error,
                title: Localization.photo_storage_full_title,
                items: makeItems(from: progress),
                text: Localization.photo_storage_full_subtitle,
                storageButton: Localization.general_get_more_storage,
                closeButton: nil,
                accessibilityIdentifier: "PhotosStorageViewData.FullStorage"
            )
        }
    }

    private func makeItems(from progress: PhotosBackupProgress?) -> String? {
        if let count = progress?.inProgress {
            let items = "**\(Localization.item_plural_type_with_num(num: count).lowercased())**"
            return Localization.photo_storage_item_left(items: items)
        } else {
            return nil
        }
    }
}
