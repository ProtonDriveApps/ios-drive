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

import Foundation
import PDLocalization

struct PhotosPermissionsViewData {
    let headline: String
    let text: String
    let button: String
}

protocol PhotosPermissionsViewModelProtocol {
    var viewData: PhotosPermissionsViewData { get }
    func openSettings()
}

final class PhotosPermissionsViewModel: PhotosPermissionsViewModelProtocol {
    private let coordinator: PhotosPermissionsCoordinator

    var viewData: PhotosPermissionsViewData {
        PhotosPermissionsViewData(
            headline: Localization.photo_permission_alert_title,
            text: Localization.photo_permission_alert_text,
            button: Localization.photo_permission_alert_button
        )
    }

    init(coordinator: PhotosPermissionsCoordinator) {
        self.coordinator = coordinator
    }

    func openSettings() {
        coordinator.openSettings()
    }
}
