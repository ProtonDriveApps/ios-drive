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

import Foundation

public final class LocalPhotosRootFolderDatasource: PhotosRootFolderDatasource {

    private let observer: FetchedResultsControllerObserver<Device>

    public init(observer: FetchedResultsControllerObserver<Device>) {
        self.observer = observer
    }

    public func getRoot() throws -> Folder {
        guard !observer.cache.isEmpty else {
            throw LocalPhotosRootDataSourceError.noLocalDevices
        }

        guard let device = observer.cache.first,
              [device] == observer.cache else {
            throw LocalPhotosRootDataSourceError.moreThanOnePhotosDevice
        }

        guard let moc = device.moc else {
            throw Device.noMOC()
        }

        return try moc.performAndWait {
            guard let rootNode = device.share.root else {
                throw LocalPhotosRootDataSourceError.noRootInPhotosShare
            }

            guard let rootFolder = rootNode as? Folder else {
                throw LocalPhotosRootDataSourceError.photosRootInNotFolder
            }
            return rootFolder
        }
    }

}

enum LocalPhotosRootDataSourceError: Error {
    case noLocalDevices
    case moreThanOnePhotosDevice
    case noRootInPhotosShare
    case photosRootInNotFolder
}
