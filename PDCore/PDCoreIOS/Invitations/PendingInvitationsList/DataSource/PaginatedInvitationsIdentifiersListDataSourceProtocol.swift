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

import PDClient
import PDCore

protocol PaginatedInvitationsIdentifiersListDataSourceProtocol {
    func getPaginatedInvitations(anchorID: String?, limit: Int?, shareTypes: Set<ShareTargetType>) async throws -> ListUserInvitationsResponse
}

extension Client: PaginatedInvitationsIdentifiersListDataSourceProtocol {
    func getPaginatedInvitations(anchorID: String?, limit: Int?, shareTypes: Set<ShareTargetType>) async throws -> ListUserInvitationsResponse {
        let parameters = ListUserInvitationsParameters(anchorID: anchorID, pageSize: limit, shareTypes: shareTypes)
        let endpoint = ListUserInvitationsEndpoint(service: service, credential: try credential(), parameters: parameters)
        return try await request(endpoint, completionExecutor: .immediateExecutor)
    }
}
