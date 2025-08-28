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

enum PhotoVolumeMigrationStatus: Equatable {
    case inProgress
    case finished(newVolumeId: VolumeID)
    case noPhotoVolume
}

protocol PhotoVolumeMigrationStatusInteractorProtocol {
    func getStatus() async throws -> PhotoVolumeMigrationStatus
}

final class PhotoVolumeMigrationStatusInteractor: PhotoVolumeMigrationStatusInteractorProtocol {
    private let apiService: PhotoShareMigrateAPIService

    init(apiService: PhotoShareMigrateAPIService) {
        self.apiService = apiService
    }

    func getStatus() async throws -> PhotoVolumeMigrationStatus {
        do {
            let status = try await apiService.getMigrationStatus()
            if let newVolumeID = status.newVolumeID {
                return .finished(newVolumeId: newVolumeID)
            } else {
                // Happens either when the user still has legacy photo share, or when they migrated, but
                // the migrated photo volume is in locked state
                return .noPhotoVolume
            }
        } catch let error as ResponseError {
            if error.httpCode == 202 && error.code == 1002 {
                // Success http code, but the response would be empty, parsing would throw an error
                Log.info("Photo volume migration is in progress", domain: .albums)
                return .inProgress
            } else if error.httpCode == 422 && error.code == 2501 {
                // Legacy photo share not found, new photo volume can be created
                Log.info("Photo volume not in progress, new volume needed.", domain: .albums)
                return .noPhotoVolume
            } else {
                Log.error("Failed to get migration status: \(error.localizedDescription)", error: error, domain: .clientNetworking)
                throw error
            }
        } catch {
            Log.error("Failed to get migration status: \(error.localizedDescription)", error: error, domain: .clientNetworking)
            throw error
        }
    }
}
