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
import UIKit

protocol ExtensionBackgroundTaskResource {
    func scheduleTask(expirationHandler: @escaping () -> Void)
    func cancelTask()
}

final class ExtensionBackgroundTaskResourceImpl: ExtensionBackgroundTaskResource {
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    func scheduleTask(expirationHandler: @escaping () -> Void) {
        Log.debug("▶️ Launching extension task.", domain: .backgroundTask)
        backgroundTask = UIApplication.shared.beginBackgroundTask(expirationHandler: expirationHandler)

#if DEBUG
        // Looks like background task won't expire in UI tests
        // Schedule a timer to simulate it
        // This workaround is for `NotificationTests`
        if DebugConstants.commandLineContains(flags: [.uiTests]) &&
            !DebugConstants.commandLineContains(flags: [.skipNotificationPermissions]) {
            Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] _ in
                self?.cancelTask()
                expirationHandler()
            }
        }
#endif
    }
    
    func cancelTask() {
        if backgroundTask != .invalid {
            Log.debug("⏸️ Cancelling extension task.", domain: .backgroundTask)
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
}
