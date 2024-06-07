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

import PDClient

final class BackendRemotePhotosTrashRepository: RemotePhotosTrashRepository {
    private let client: Client
    private let rootIdDataSource: PhotosFolderIdDataSource

    init(client: Client, rootIdDataSource: PhotosFolderIdDataSource) {
        self.client = client
        self.rootIdDataSource = rootIdDataSource
    }

    func trash(with data: PhotosTrashData) async throws -> RemotePhotosTrashResult {
        let rootId = try rootIdDataSource.getRootId()
        let parameters = TrashLinksParameters(shareId: data.shareId, parentLinkId: rootId, linkIds: data.nodeIds)
        let response = try await client.trashNodes(parameters: parameters, breadcrumbs: .startCollecting())
        let ids = response.responses.compactMap { $0.response.error == nil ? $0.linkID : nil }
        return RemotePhotosTrashResult(trashed: ids)
    }
}
