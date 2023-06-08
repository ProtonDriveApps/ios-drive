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

enum PhotoLibraryPermissions {
    case undetermined
    case restricted
    case full
}

protocol PhotoLibraryAuthorizationController {
    var permissions: AnyPublisher<PhotoLibraryPermissions, Never> { get }
    func authorize()
}

final class LocalPhotoLibraryAuthorizationController: PhotoLibraryAuthorizationController {
    private let resource: PhotoLibraryAuthorizationResource
    private let permissionsSubject = CurrentValueSubject<PhotoLibraryPermissions, Never>(.undetermined)
    private var cancellables = Set<AnyCancellable>()

    var permissions: AnyPublisher<PhotoLibraryPermissions, Never> {
        permissionsSubject.eraseToAnyPublisher()
    }

    init(resource: PhotoLibraryAuthorizationResource) {
        self.resource = resource
        resource.permissions
            .removeDuplicates()
            .sink { [weak self] value in
                self?.permissionsSubject.send(value)
            }
            .store(in: &cancellables)
    }

    func authorize() {
        resource.authorize()
    }
}
