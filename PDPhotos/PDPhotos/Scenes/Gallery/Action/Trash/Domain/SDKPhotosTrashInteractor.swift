// Copyright (c) 2026 Proton AG
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

import CoreData
import Foundation
import PDCore

final class SDKPhotosTrashInteractor: ThrowingAsynchronousInteractor {
    private let downloader: DownloaderProtocol
    private let performer: SDKNodeOperationPerformer

    init(downloader: DownloaderProtocol, performer: SDKNodeOperationPerformer) {
        self.downloader = downloader
        self.performer = performer
    }

    func execute(with input: PhotoIdsSet) async throws {
        let (affectedIDs, error) = try await performer.trash(nodes: Array(input))
        downloader.cancel(operationsOf: affectedIDs)
        if let error {
            throw error
        }
    }
}
