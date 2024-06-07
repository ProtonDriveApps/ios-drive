//
//  FileManager+info.swift
//  ProtonCore-Challenge - Created on 6/18/20.
//
//  Copyright (c) 2022 Proton Technologies AG
//
//  This file is part of Proton Technologies AG and ProtonCore.
//
//  ProtonCore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonCore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonCore.  If not, see <https://www.gnu.org/licenses/>.

import Foundation

// MARK: Jail break
extension FileManager {
    static func isJailbroken() -> Bool {
        guard TARGET_IPHONE_SIMULATOR != 1 else { return false }

        // Check 1 : existence of files that are common for jailbroken devices
        let checkList = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt/"
        ]
        for path in checkList {
            if FileManager.default.fileExists(atPath: path) {
                // Uncommon file exists
                return true
            }
            if canOpen(path: path) {
                return true
            }
        }

        let path = "/private/" + UUID().uuidString
        do {
            try "anyString".write(toFile: path, atomically: true, encoding: String.Encoding.utf8)
            try FileManager.default.removeItem(atPath: path)
            //            PMLog.info("[Jailbreak detection]:\tCreate file in /private/.")
            return true
        } catch {
            return false
        }
    }

    private static func canOpen(path: String) -> Bool {
        let file = fopen(path, "r")
        guard file != nil else { return false }
        fclose(file)
        return true
    }
}
