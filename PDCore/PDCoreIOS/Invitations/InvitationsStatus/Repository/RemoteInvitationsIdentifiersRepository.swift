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
import PDClient

final class RemoteInvitationsIdentifiersRepository: InvitationsIdentifiersRepositoryProtocol {
    private let remoteDataSource: PaginatedInvitationsIdentifiersListDataSourceProtocol
    private let configuration: PendingInvitationsConfiguration

    init(remoteDataSource: PaginatedInvitationsIdentifiersListDataSourceProtocol, configuration: PendingInvitationsConfiguration) {
        self.remoteDataSource = remoteDataSource
        self.configuration = configuration
    }

    func getInvitations() async throws -> [InvitationIdentifier] {
        let response = try await remoteDataSource.getPaginatedInvitations(anchorID: nil, limit: makeLimit(), shareTypes: configuration.shareTypes)
        return response.invitations.map { InvitationIdentifier(volumeId: $0.volumeID, shareID: $0.shareID, invitationId: $0.invitationID) }
    }

    private func makeLimit() -> Int {
        switch configuration {
        case .default:
            return 11
        case .albums:
            return 1
        }
    }
}
