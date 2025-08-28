// Copyright (c) 2025 Proton AG
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
import PDCore

public struct SharedLink: Equatable {
    public let id: String
    public let shareID: String
    public let link: String
    public let publicUrl: String
    public let invariantPassword: String
    public let customPassword: String
    public let fullPassword: String
    public let expirationDate: Date?
    public let isCustom: Bool
    public let isLegacy: Bool
    public let publicLinkIdentifier: PublicLinkIdentifier

    public init(id: String, shareID: String, publicUrl: String, fullPassword: String, expirationDate: Date?, isCustom: Bool, isLegacy: Bool, publicLinkIdentifier: PublicLinkIdentifier) {
        let defaultPasswordSize = PDCore.Constants.minSharedLinkRandomPasswordSize
        self.id = id
        self.shareID = shareID
        self.expirationDate = expirationDate
        self.invariantPassword = String(fullPassword.prefix(defaultPasswordSize))
        self.customPassword = String(fullPassword.dropFirst(defaultPasswordSize))
        self.fullPassword = fullPassword
        self.publicUrl = publicUrl
        self.link = publicUrl.appending("#" + invariantPassword)
        self.isCustom = isCustom
        self.isLegacy = isLegacy
        self.publicLinkIdentifier = publicLinkIdentifier
    }

    public init(shareURL: ShareURL) throws {
        let password = try shareURL.decryptPassword()
        self = SharedLink(id: shareURL.id, shareID: shareURL.shareID, publicUrl: shareURL.publicUrl, fullPassword: password, expirationDate: shareURL.expirationTime, isCustom: shareURL.hasCustomPassword, isLegacy: !shareURL.hasNewFormat, publicLinkIdentifier: shareURL.identifier)
    }

}

extension SharedLink {
    public func updated(with details: UpdateShareURLDetails, shareURL: ShareURL) -> SharedLink {
        let updatedPassword = details.updatedPassword ?? fullPassword
        let updatedExpiration: Date?
        if let date = details.updatedExpiration {
            updatedExpiration = Date(timeIntervalSince1970: date)
        } else {
            updatedExpiration = expirationDate
        }
        return SharedLink(
            id: id,
            shareID: shareID,
            publicUrl: publicUrl,
            fullPassword: updatedPassword,
            expirationDate: updatedExpiration,
            isCustom: shareURL.hasCustomPassword,
            isLegacy: isLegacy,
            publicLinkIdentifier: shareURL.identifier
        )
    }
}

private extension UpdateShareURLDetails {
    var updatedPassword: String? {
        switch password {
        case .updated(let newPassword):
            return newPassword
        default:
            return nil
        }
    }

    var updatedExpiration: TimeInterval? {
        switch duration {
        case .expiring(let newExpiration):
            return newExpiration
        case .nonExpiring:
            return .zero
        default:
            return nil
        }
    }
}
