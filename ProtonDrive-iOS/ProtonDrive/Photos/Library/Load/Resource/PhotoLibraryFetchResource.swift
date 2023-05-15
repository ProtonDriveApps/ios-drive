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

enum PhotoLibraryFetchResourceError: Error {
    case missingMapping
}

final class LocalPhotoLibraryFetchResource: PhotoLibraryIdentifiersResource {
    private let mappingResource: PhotoLibraryMappingResource
    private let updateSubject = PassthroughSubject<PhotoIdentifiers, Never>()
    private var task: Task<Void, Never>?

    var updatePublisher: AnyPublisher<PhotoIdentifiers, Never> {
        updateSubject.eraseToAnyPublisher()
    }

    init(mappingResource: PhotoLibraryMappingResource) {
        self.mappingResource = mappingResource
    }

    func execute() {
        cancel()
        task = Task(priority: .medium) { [weak self] in
            let identifiers = self?.getIdentifiers() ?? []
            await self?.finish(with: identifiers)
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }

    private func getIdentifiers() -> PhotoIdentifiers {
        let assetsResult = PHAsset.fetchAssets(with: nil)
        var assets = [PHAsset]()
        assetsResult.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return mappingResource.map(assets: assets)
    }

    @MainActor
    private func finish(with identifiers: PhotoIdentifiers) {
        updateSubject.send(identifiers)
    }
}
