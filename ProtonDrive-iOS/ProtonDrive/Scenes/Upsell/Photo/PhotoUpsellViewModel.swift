// Copyright (c) 2024 Proton AG
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

final class PhotoUpsellViewModel: ObservableObject {
    
    var upsellTitle: String { Localization.photo_upsell_title }
    var upsellSubtitle: String { Localization.photo_upsell_subtitle }
    var upgradeButtonTitle: String { Localization.general_get_more_storage }
    var skipButtonTitle: String { Localization.general_not_now }

    private let dismiss: () -> Void
    private let photosCoordinator: PhotosStorageCoordinator
    private let photoUpsellResultNotifier: PhotoUpsellResultNotifierProtocol
    private var isButtonClicked = false

    init(
        photosCoordinator: PhotosStorageCoordinator,
        photoUpsellResultNotifier: PhotoUpsellResultNotifierProtocol,
        dismiss: @escaping () -> Void
    ) {
        self.photosCoordinator = photosCoordinator
        self.photoUpsellResultNotifier = photoUpsellResultNotifier
        self.dismiss = dismiss
    }
    
    func upgradeButtonDidTap() {
        isButtonClicked = true
        dismiss()
        photoUpsellResultNotifier.notify(.accepted)
        photosCoordinator.openSubscriptions()
    }
    
    func skipButtonDidTap() {
        isButtonClicked = true
        dismiss()
        photoUpsellResultNotifier.notify(.declined)
    }
    
    func onDisappear() {
        if isButtonClicked { return }
        // Dismiss upsell view by drag down 
        photoUpsellResultNotifier.notify(.declined)
    }
}
