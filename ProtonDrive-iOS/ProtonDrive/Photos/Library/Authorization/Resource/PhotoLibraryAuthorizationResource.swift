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

import Combine
import Photos

protocol PhotoLibraryAuthorizationResource {
    var permissions: AnyPublisher<PhotoLibraryPermissions, Never> { get }
    func authorize()
}

final class LocalPhotoLibraryAuthorizationResource: PhotoLibraryAuthorizationResource {
    private let permissionsSubject = CurrentValueSubject<PhotoLibraryPermissions, Never>(.undetermined)

    var permissions: AnyPublisher<PhotoLibraryPermissions, Never> {
        permissionsSubject.eraseToAnyPublisher()
    }

    init() {
        update()
    }

    func authorize() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] _ in
            DispatchQueue.main.async {
                self?.update()
            }
        }
    }

    private func update() {
        let permissions = getPermissions()
        permissionsSubject.send(permissions)
    }

    private func getPermissions() -> PhotoLibraryPermissions {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized:
            return .full
        case .notDetermined:
            return .undetermined
        case .denied, .limited, .restricted:
            return .restricted
        @unknown default:
            return .restricted
        }
    }
}
