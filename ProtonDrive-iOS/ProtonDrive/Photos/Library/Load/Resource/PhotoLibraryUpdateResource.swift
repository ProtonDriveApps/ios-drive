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
import PDCore

final class LocalPhotoLibraryUpdateResource: NSObject, PhotoLibraryIdentifiersResource, PHPhotoLibraryChangeObserver {
    private let updateSubject = PassthroughSubject<PhotoIdentifiers, Never>()
    private let mappingResource: PhotoLibraryMappingResource

    var updatePublisher: AnyPublisher<PhotoIdentifiers, Never> {
        updateSubject.eraseToAnyPublisher()
    }

    init(mappingResource: PhotoLibraryMappingResource) {
        self.mappingResource = mappingResource
    }

    func execute() {
        PHPhotoLibrary.shared().register(self)
    }

    func cancel() {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    // MARK: - PHPhotoLibraryChangeObserver

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        let fetchResult = PHAsset.fetchAssets(with: nil)
        let details = changeInstance.changeDetails(for: fetchResult)
        let insertedObjects = details?.insertedObjects ?? []
        let changedObjects = details?.changedObjects ?? []
        let assets = mappingResource.map(assets: insertedObjects + changedObjects)
        DispatchQueue.main.async { [weak self] in
            self?.updateSubject.send(assets)
        }
    }
}
