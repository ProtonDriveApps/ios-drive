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

import PDCore
import PDCoreIOS

final class PhotosCacheBootstrapper: AppBootstrapper {
    private let previousUserRepository: PreviouslyLoggedInUserRepositoryProtocol
    private let photosSkippableStorage: PhotosSkippableStorage

    init(previousUserRepository: PreviouslyLoggedInUserRepositoryProtocol, photosSkippableStorage: PhotosSkippableStorage) {
        self.previousUserRepository = previousUserRepository
        self.photosSkippableStorage = photosSkippableStorage
    }

    func bootstrap() async throws {
        try measure(message: "photos cache bootstrap", domain: .applicationBootstrap) {
            let user = try previousUserRepository.getPreviousUser()
            switch user {
            case .differentUser:
                // New user, need to replace the hash and wipe the photos cache
                Log.info("Different user logged in, cleaning up photos cache", domain: .photosProcessing)
                photosSkippableStorage.clean()
                try previousUserRepository.storeCurrentUser()
            case .sameUser:
                // Same user is logged in, we can keep cache
                Log.info("Same user logged in, keeping photos cache intact.", domain: .photosProcessing)
            case .missingInfo:
                // Happens when upgrading app from version 1.45.0 or new install
                Log.warning("There's no user hash stored, skipping photos cache cleanup", domain: .photosProcessing)
                try previousUserRepository.storeCurrentUser()
            }
        }
    }
}
