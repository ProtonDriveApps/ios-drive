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

struct LocalNotification: Equatable {
    let id: String
    let title: String
    let body: String
    let thread: String
    let delay: TimeInterval

    static var interruptedPhotoUpload: LocalNotification {
        LocalNotification(
            id: "ch.protondrive.usernotification.uploadIncomplete",
            title: "Proton Drive",
            body: "Photo backup is slower in the background. Open the app for quicker uploads.",
            thread: "ch.protondrive.usernotification.uploadIncomplete",
            delay: 10.0
        )
    }

    static var interruptedFileUpload: LocalNotification {
        LocalNotification(
            id: "ch.protondrive.usernotification.uploadIncomplete",
            title: "Proton Drive",
            body: "File upload paused. Open the app to resume.",
            thread: "ch.protondrive.usernotification.uploadIncomplete",
            delay: 1.0
        )
    }

    static var failedUpload: LocalNotification {
        LocalNotification(
            id: "ch.protondrive.usernotification.uploadFailure",
            title: "Proton Drive",
            body: "Some files didn’t upload. Try uploading them again.",
            thread: "ch.protondrive.usernotification.uploadFailure",
            delay: 1.0
        )
    }
}
