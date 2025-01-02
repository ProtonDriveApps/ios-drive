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

import CoreData
import Foundation
import PDCore
import PDClient

protocol MainVolumeIdDataSourceProtocol {
    func getMainVolumeId() async throws -> String
}

final class MainVolumeIdDataSource: MainVolumeIdDataSourceProtocol {
    private let storage: StorageManager
    private let context: NSManagedObjectContext

    init(storage: StorageManager, context: NSManagedObjectContext) {
        self.storage = storage
        self.context = context
    }

    func getMainVolumeId() async throws -> String {
        return try await context.perform {
            let shares = self.storage.getMainShares(in: self.context)
            return try self.getMainVolumeId(from: shares)
        }
    }

    private func getMainVolumeId(from shares: [PDCore.Share]) throws -> String {
        let shares = shares
            .filter { $0.type == .main }
            .filter { $0.state == .active }

        guard shares.count < 2 else {
            throw NukingCacheError("There are multiple main shares in the local DB")
        }

        guard let mainShare = shares.first else {
            throw NukingCacheError("There is no main share in the local DB")
        }

        guard let volume = mainShare.volume, !volume.id.isEmpty else {
            throw NukingCacheError("Main share has no volume downloaded")
        }

        return volume.id
    }
}
