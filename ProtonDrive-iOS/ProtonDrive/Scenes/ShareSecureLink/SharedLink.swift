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
import Foundation

struct SharedLink: Equatable {
    let id: String
    let shareID: String
    let link: String
    let publicUrl: String
    let invariantPassword: String
    let customPassword: String
    let fullPassword: String
    let expirationDate: Date?
    let isCustom: Bool
    let isLegacy: Bool

    init(id: String, shareID: String, publicUrl: String, fullPassword: String, expirationDate: Date?, isCustom: Bool, isLegacy: Bool) {
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
    }

    init(shareURL: ShareURL) throws {
        let password = try shareURL.decryptPassword()
        self = SharedLink(id: shareURL.id, shareID: shareURL.shareID, publicUrl: shareURL.publicUrl, fullPassword: password, expirationDate: shareURL.expirationTime, isCustom: shareURL.hasCustomPassword, isLegacy: !shareURL.hasNewFormat)
    }

}

extension SharedLink {
    func updated(with details: UpdateShareURLDetails, shareURL: ShareURL) -> SharedLink {
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
            isLegacy: isLegacy
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
