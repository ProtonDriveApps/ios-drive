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

public struct AccessPermission: OptionSet, Codable {
    public let rawValue: Int
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public static let write = AccessPermission(rawValue: 1 << 1)
    public static let read = AccessPermission(rawValue: 1 << 2)
    public static let admin = AccessPermission(rawValue: 1 << 4)
    
    public var isEditor: Bool {
        self.contains([.read, .write])
    }
    
    public func toRequestPermission() -> ShareURLMeta.Permissions {
        isEditor ? [.read, .write] : [.read]
    }
}

public enum ExternalInviteState: Int, Codable {
    case pending = 1
    case registered = 2
}

public struct ShareMemberInvitation: Codable {
    public let invitationID: String
    public let inviterEmail: String
    public let inviteeEmail: String
    public let permissions: AccessPermission
    public let keyPacket: String
    public let keyPacketSignature: String
    public let createTime: Date
    
    public init(
        invitationID: String,
        inviterEmail: String,
        inviteeEmail: String,
        permissions: AccessPermission,
        keyPacket: String,
        keyPacketSignature: String,
        createTime: Date
    ) {
        self.invitationID = invitationID
        self.inviterEmail = inviterEmail
        self.inviteeEmail = inviteeEmail
        self.permissions = permissions
        self.keyPacket = keyPacket
        self.keyPacketSignature = keyPacketSignature
        self.createTime = createTime
    }
}

public struct ExternalInvitation: Codable {
    public let createTime: Date
    public let externalInvitationID: String
    public let externalInvitationSignature: String
    public let inviteeEmail: String
    public let inviterEmail: String
    public let permissions: AccessPermission
    public let state: ExternalInviteState
    
    public init(
        externalInvitationID: String,
        inviterEmail: String,
        inviteeEmail: String,
        permissions: AccessPermission,
        externalInvitationSignature: String,
        state: ExternalInviteState,
        createTime: Date
    ) {
        self.externalInvitationID = externalInvitationID
        self.inviterEmail = inviterEmail
        self.inviteeEmail = inviteeEmail
        self.permissions = permissions
        self.externalInvitationSignature = externalInvitationSignature
        self.state = state
        self.createTime = createTime
    }
}

public struct ShareMember: Codable {
    public let createTime: Date
    public let email: String
    public let inviterEmail: String
    public let keyPacket: String
    public let keyPacketSignature: String
    public let memberID: String
    public let permissions: AccessPermission
    public let sessionKeySignature: String
    
    public init(
        createTime: Date,
        email: String,
        inviterEmail: String,
        keyPacket: String,
        keyPacketSignature: String,
        memberID: String,
        permissions: AccessPermission,
        sessionKeySignature: String
    ) {
        self.createTime = createTime
        self.email = email
        self.inviterEmail = inviterEmail
        self.keyPacket = keyPacket
        self.keyPacketSignature = keyPacketSignature
        self.memberID = memberID
        self.permissions = permissions
        self.sessionKeySignature = sessionKeySignature
    }
}
