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

final class CrossProcessNotifier {
    private let label: String
    private let notificationCenter: DarwinNotificationCenter
    
    private var darwinNotificationNameToListen: DarwinNotification.Name
    private var darwinNotificationNameToPost: DarwinNotification.Name
    
    internal init(notificationCenter: DarwinNotificationCenter, label: String, onReceive: @escaping (DarwinNotification) -> Void) {
        self.notificationCenter = notificationCenter
        self.label = label
        
        let extensionDidSave = DarwinNotification.Name("ch.protonmail.drive.DidSaveFromAppex." + label)
        let appDidSave = DarwinNotification.Name("ch.protonmail.drive.DidSaveFromApp." + label)
        
        self.darwinNotificationNameToListen = Constants.runningInExtension ? appDidSave : extensionDidSave
        self.darwinNotificationNameToPost = Constants.runningInExtension ? extensionDidSave : appDidSave
        
        notificationCenter.addObserver(self, for: darwinNotificationNameToListen, using: onReceive)
    }

    internal func post() {
        notificationCenter.postNotification(darwinNotificationNameToPost)
    }
}
