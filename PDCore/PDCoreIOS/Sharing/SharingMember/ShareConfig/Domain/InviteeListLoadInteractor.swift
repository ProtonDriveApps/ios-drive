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

import Combine
import PDClient
import PDCore

public typealias InviteeListLoadResult = Result<[InviteeInfo], Error>

public protocol InviteeListLoadInteractor {
    var result: AnyPublisher<InviteeListLoadResult, Never> { get }
    func execute(with shareID: String)
}

public final class AsyncRemoteInviteeListLoadInteractor: ThrowingAsynchronousFacade<RemoteInviteeListLoadInteractor, String, [InviteeInfo]>, InviteeListLoadInteractor {}

public final class RemoteInviteeListLoadInteractor: ThrowingAsynchronousInteractor {
    private let client: ShareMemberAPIClient & ShareInvitationAPIClient

    public init(client: ShareMemberAPIClient & ShareInvitationAPIClient) {
        self.client = client
    }
    
    public func execute(with shareID: String) async throws -> [InviteeInfo] {
        // If ShareID is empty, it indicates that the file has not been shared with anyone.
        if shareID.isEmpty { return [] }
        let internalList = try await listInternalInvitations(shareID: shareID)
        let externalList = try await listExternalInvitations(shareID: shareID)
        let acceptedList = try await listShareMember(shareID: shareID)
        let list = internalList
            .appending(externalList)
            .appending(acceptedList)
            .sorted { $0.createTime <= $1.createTime }
        return list
    }
    
    private func listInternalInvitations(shareID: String) async throws -> [InviteeInfo] {
        if shareID.isEmpty { return [] }
        return try await client.listInvitations(shareID: shareID)
    }
    
    private func listExternalInvitations(shareID: String) async throws -> [InviteeInfo] {
        if shareID.isEmpty { return [] }
        return try await client.listExternalInvitations(shareID: shareID)
    }
    
    private func listShareMember(shareID: String) async throws -> [InviteeInfo] {
        if shareID.isEmpty { return [] }
        return try await client.listShareMember(id: shareID)
    }
}
