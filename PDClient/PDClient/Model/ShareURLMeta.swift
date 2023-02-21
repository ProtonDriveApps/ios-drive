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

public struct ShareURLMeta: Codable {
    public typealias Token = String
    public typealias ID = String

    public let token: Token
    public let shareURLID: ID
    public let shareID: Share.ShareID
    public let expirationTime: TimeInterval?
    public let lastAccessTime: TimeInterval?
    public let maxAccesses: Int
    public let numAccesses: Int
    public let name: String?
    public let creatorEmail: String
    public let permissions: Permissions
    public let createTime: TimeInterval
    public let flags: Flags
    public let urlPasswordSalt: String
    public let sharePasswordSalt: String
    public let SRPVerifier: String
    public let SRPModulusID: String
    public let password: String
    public let publicUrl: String
    public let sharePassphraseKeyPacket: String

    public enum Flags: Int, Codable {
        case legacyRandomPassword = 0
        case legacyCustomPassword = 1
        case newRandomPassword = 2
        case newCustomPassword = 3

        public static let customPasswordFlags: [Flags] = [
            Flags.legacyCustomPassword,
            Flags.newCustomPassword
        ]

        public static let newFormatPasswordFlags: [Flags] = [
            .newRandomPassword,
            .newCustomPassword
        ]
    }

    public struct Permissions: OptionSet, Codable {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let write = Permissions(rawValue: 1 << 1)
        public static let read = Permissions(rawValue: 1 << 2)
    }
}
