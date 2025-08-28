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

struct PhotosOnboardingViewData {
    let title: String
    let rows: [Row]
    let button: String

    struct Row: Identifiable {
        var id: String {
            title
        }

        let icon: Icon
        let title: String
        let subtitle: String

        enum Icon {
            case lock
            case rotatingArrows
        }
    }
}

protocol PhotosOnboardingViewModelProtocol {
    var data: PhotosOnboardingViewData { get }
    func enableBackup()
}

final class PhotosOnboardingViewModel: PhotosOnboardingViewModelProtocol {
    private let startController: PhotosBackupStartController

    lazy var data: PhotosOnboardingViewData = makeData()

    init(startController: PhotosBackupStartController) {
        self.startController = startController
    }

    func enableBackup() {
        startController.start()
    }

    private func makeData() -> PhotosOnboardingViewData {
        PhotosOnboardingViewData(
            title: Localization.photo_onboarding_title,
            rows: [
                .init(
                    icon: .lock,
                    title: Localization.photo_onboarding_protect_memories,
                    subtitle: Localization.photo_onboarding_e2e
                ),
                .init(
                    icon: .rotatingArrows,
                    title: Localization.photo_onboarding_effortless_backups,
                    subtitle: Localization.photo_onboarding_keep_quality
                ),
            ],
            button: Localization.photo_onboarding_button_enable
        )
    }
}
