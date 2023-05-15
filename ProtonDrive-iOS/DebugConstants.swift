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

#if DEBUG

import Foundation

struct UITestsFlag {
    let content: String
    
    static let uiTests = UITestsFlag(content: "--uitests")
    static let clearAllPreference = UITestsFlag(content: "--clear_all_preference")
    static let skipNotificationPermissions = UITestsFlag(content: "--skip_notifications_permissions")
    static let skipOnboarding = UITestsFlag(content: "--skip_onboarding")
    static let defaultOnboarding = UITestsFlag(content: "--default_onboarding")
}

struct DebugConstants {
    static func commandLineContains(flags: [UITestsFlag]) -> Bool {
        let flagsRaw = flags.map(\.content)
        return Set(CommandLine.arguments).isSuperset(of: flagsRaw)
    }
    
    static func removeCommandLine(flags: [UITestsFlag]) {
        let flagsRaw = flags.map(\.content)
        let flagsToKeep = Set(ProcessInfo.processInfo.arguments).subtracting(flagsRaw)
        CommandLine.arguments = Array(flagsToKeep)
    }
}

#endif
