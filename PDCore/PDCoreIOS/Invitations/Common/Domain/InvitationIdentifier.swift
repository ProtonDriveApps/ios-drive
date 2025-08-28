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

public struct InvitationIdentifier: Equatable, Hashable {
    public let volumeId: String
    public let shareID: String
    public let invitationId: String

    public init(volumeId: String, shareID: String, invitationId: String) {
        self.volumeId = volumeId
        self.shareID = shareID
        self.invitationId = invitationId
    }
}
