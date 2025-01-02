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

import CoreData
import Foundation

public final class LocalPhotosRootFolderDatasource: PhotosRootFolderDatasource {

    private let observer: FetchedResultsControllerObserver<Share>

    public init(observer: FetchedResultsControllerObserver<Share>) {
        self.observer = observer
    }

    public func getRoot() throws -> Folder {
        let cache = observer.cache
        guard !cache.isEmpty else {
            throw LocalPhotosRootDataSourceError.noLocalPhotoShare
        }

        guard let share = cache.first,
              [share] == cache else {
            throw LocalPhotosRootDataSourceError.moreThanOnePhotoShare
        }

        guard let moc = share.moc else {
            throw Share.noMOC()
        }

        return try moc.performAndWait {
            guard let rootNode = share.root else {
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
    case noLocalPhotoShare
    case moreThanOnePhotoShare
    case noRootInPhotosShare
    case photosRootInNotFolder
}
