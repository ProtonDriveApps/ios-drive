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
            title: "Encrypt and back up your photos and videos",
            rows: [
                .init(
                    icon: .lock,
                    title: "Protect your memories",
                    subtitle: "Your photos are end-to-end encrypted, ensuring total privacy."
                ),
                .init(
                    icon: .rotatingArrows,
                    title: "Effortless backups",
                    subtitle: "Photos are backed up over WiFi in their original quality."
                ),
            ],
            button: "Turn on backup"
        )
    }
}
