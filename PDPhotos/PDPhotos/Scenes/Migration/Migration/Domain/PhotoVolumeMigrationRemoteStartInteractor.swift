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

import PDCore
import ProtonCoreNetworking

protocol PhotoVolumeMigrationRemoteStartInteractorProtocol {
    func startMigration() async throws
}

final class PhotoVolumeMigrationRemoteStartInteractor: PhotoVolumeMigrationRemoteStartInteractorProtocol {
    private let apiService: PhotoShareMigrateAPIService

    init(apiService: PhotoShareMigrateAPIService) {
        self.apiService = apiService
    }

    func startMigration() async throws {
        Log.info("Starting photo volume migration", domain: .albums)
        do {
            try await apiService.migratePhotoShare()
        } catch let error as ResponseError {
            if error.httpCode == 202 && error.code == 1002 {
                // Successfully triggered migration.
                // Should not throw an error (needs to be handled API level once ProtonCore is updated)
                Log.info("Photo volume migration was triggered successfully", domain: .albums)
                return
            } else if error.httpCode == 422 && error.code == 2500 {
                // Migration already in progress
                Log.info("Photo volume migration is already in progress", domain: .albums)
                return
            } else if error.httpCode == 422 && error.code == 2501 {
                Log.error("Photo volume exists or photo share not found: \(error.localizedDescription)", error: error, domain: .clientNetworking)
                throw error
            } else if error.httpCode == 422 && error.code == 201_102 {
                Log.error("Photo volume restore in progress: \(error.localizedDescription)", error: error, domain: .clientNetworking)
                throw error
            } else if error.httpCode == 424 && error.code == 2501 {
                Log.error("Albums FF disabled, migration not possible: \(error.localizedDescription)", error: error, domain: .clientNetworking)
                throw error
            } else {
                Log.error("Failed to start photo volume migration: \(error.localizedDescription)", error: error, domain: .clientNetworking)
                throw error
            }
        } catch {
            Log.error("Failed to start photo volume migration: \(error.localizedDescription)", error: error, domain: .clientNetworking)
            throw error
        }
    }
}
