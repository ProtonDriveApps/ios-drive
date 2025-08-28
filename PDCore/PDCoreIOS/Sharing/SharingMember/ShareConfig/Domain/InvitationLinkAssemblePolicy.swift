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
import PDCore

protocol InvitationLinkAssemblePolicyProtocol {
    func assembleLink(parameters: InvitationLinkAssembleParameters) -> URL?
}

struct InvitationLinkAssembleParameters {
    let volumeID: String
    let linkID: String
    let invitationID: String
    let inviteeEmail: String
}

struct InvitationLinkAssemblePolicy: InvitationLinkAssemblePolicyProtocol {
    private let baseHost: String
    
    init(baseHost: String) {
        self.baseHost = baseHost
    }

    func assembleLink(parameters: InvitationLinkAssembleParameters) -> URL? {
        var component = URLComponents()
        component.scheme = "https"
        component.host = "drive.\(baseHost)"
        component.path = "/\(parameters.volumeID)/\(parameters.linkID)"
        component.queryItems = [
            .init(name: "invitation", value: parameters.invitationID),
            .init(name: "email", value: parameters.inviteeEmail)
        ]
        guard let url = component.url else { return nil }
        return url
    }
}
