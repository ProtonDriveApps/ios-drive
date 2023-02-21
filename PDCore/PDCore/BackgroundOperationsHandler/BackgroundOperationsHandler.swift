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

import UserNotifications

#if canImport(UIKit)
import UIKit
#endif

final class BackgroundOperationsHandler {
    public static func requestNotificationsHandling() {
        #if DEBUG
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .provisional],
            completionHandler: { _, _ in }
        )
        #endif
    }

    public static func handle(_ operation: Operation?, id: String, onExpiration: (() -> Void)? = nil) {
        #if canImport(UIKit)
        // FIXME: This will not work in app extensions
        
        guard let operation = operation else { return }
        let identifier = UIApplication.shared.beginBackgroundTask(withName: id) {
            onExpiration?()
            operation.cancel()
        }

        operation.completionBlock = {
            UIApplication.shared.endBackgroundTask(identifier)
        }

        #endif
    }
}
