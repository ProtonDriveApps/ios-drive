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

#if DEBUG

import Foundation

public struct UITestsFlag {
    let content: String

    public static let uiTests = UITestsFlag(content: "--uitests")

    public init(content: String) {
        self.content = content
    }
}

public struct DebugConstants {
    public static func commandLineContains(flags: [UITestsFlag]) -> Bool {
        let flagsRaw = flags.map(\.content)
        return Set(CommandLine.arguments).isSuperset(of: flagsRaw)
    }

    public static func removeCommandLine(flags: [UITestsFlag]) {
        let flagsRaw = flags.map(\.content)
        let flagsToKeep = Set(CommandLine.arguments).subtracting(flagsRaw)
        CommandLine.arguments = Array(flagsToKeep)
    }
}

#endif
