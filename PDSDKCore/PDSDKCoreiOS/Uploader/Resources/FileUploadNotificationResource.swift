// Copyright (c) 2026 Proton AG
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
import UserNotifications
import PDCore
import UIKit

@MainActor
protocol FileUploadNotificationResourceProtocol {
    func notify(start: Bool)
    func notify(error: FileUploadInteractorError)
}

@MainActor
final class FileUploadNotificationResource: FileUploadNotificationResourceProtocol {
    func notify(start: Bool) {
        guard shouldNotify() else {
            return
        }
        let content = UNMutableNotificationContent()
        content.title = "Proton Drive"
        content.body = "Did \(start ? "start" : "finish") SDK upload"
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: .leastNonzeroMagnitude, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    func notify(error: FileUploadInteractorError) {
        guard shouldNotify() else {
            return
        }
        let content = UNMutableNotificationContent()
        content.title = "Proton Drive"
        switch error {
        case .cancelled:
            content.body = "Upload cancelled"
        case .paused:
            content.body = "Upload paused"
        case let .error(error):
            content.body = "Upload failed: \(error.localizedDescription)"
        }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: .leastNonzeroMagnitude, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    private func shouldNotify() -> Bool {
        guard Constants.buildType.isQaOrBelow else {
            return false
        }
        return UIApplication.shared.applicationState != .active
    }
}
