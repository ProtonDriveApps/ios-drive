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

#if os(iOS)
public extension DarwinNotification.Name {
    static var DidLogout = DarwinNotification.Name("ch.protonmail.drive.DidLogout")
}
#endif

// Approach by Antoine van der Lee from WeTransfer:  https://www.avanderlee.com/swift/core-data-app-extension-data-sharing
extension DarwinNotification.Name {
    // The relevant DarwinNotification name to observe when the managed object context has been saved in an external process.
    static var DidSaveManagedObjectContextExternally: DarwinNotification.Name {
        Constants.runningInExtension ? AppDidSaveMOC : ExtensionDidSaveMOC
    }

    // The notification to post when a managed object context has been saved and stored to the persistent store.
    static var DidSaveManagedObjectContextLocally: DarwinNotification.Name {
        Constants.runningInExtension ? ExtensionDidSaveMOC : AppDidSaveMOC
    }

    // Notification to be posted when the shared Core Data database has been saved to disk from an extension. Posting this notification between processes can help us fetching new changes when needed.
    private static var ExtensionDidSaveMOC = DarwinNotification.Name("ch.protonmail.drive.DidSaveMOCFromAppex")

    // Notification to be posted when the shared Core Data database has been saved to disk from the app. Posting this notification between processes can help us fetching new changes when needed.
    private static var AppDidSaveMOC = DarwinNotification.Name("ch.protonmail.drive.DidSaveMOCFromApp")
}

#if HAS_QA_FEATURES
public extension DarwinNotification.Name {
    static var SendErrorEventToTestSentry = DarwinNotification.Name("ch.protonmail.drive.qa.SendErrorEventToTestSentry")
    static var DoCrashToTestSentry = DarwinNotification.Name("ch.protonmail.drive.qa.DoCrashToTestSentry")
}
#endif
