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
import Combine
import CoreData

public final class InMemoryCachingEncryptingPhotosRootRepository: PhotosRootFolderRepository {
    private let datasource: PhotosRootFolderDatasource
    private let photosShareObserver: FetchedResultsControllerObserver<Share>
    private var cancellable: AnyCancellable?
    private let dispatchQueue = DispatchQueue(label: "PhotosRootFolderRepository.queue", qos: .background, attributes: .concurrent)
    private let context: NSManagedObjectContext

    @ThreadSafe private var cachedInfo: FolderEncryptionInfo?

    public init(
        datasource: PhotosRootFolderDatasource,
        photosShareObserver: FetchedResultsControllerObserver<Share>
    ) {
        _cachedInfo = ThreadSafe(wrappedValue: nil, queue: dispatchQueue)
        self.datasource = datasource
        self.photosShareObserver = photosShareObserver
        self.context = photosShareObserver.fetchedResultsController.managedObjectContext
        Log.info("[\(type(of: self))] Starting photos root folder cache", domain: .storage)

        // Invalidate cached value on share changes
        self.cancellable = self.photosShareObserver.getPublisher()
            .receive(on: DispatchQueue.global())
            .compactMap { shares in
                self.context.performAndWait {
                    return shares.map(\.id)
                }
            }
            .removeDuplicates()
            .sink { [weak self] _ in
                Log.info("[\(type(of: self))] There was a change in photos shares, invalidating cached encryption info", domain: .storage)
                self?.cachedInfo = nil
            }
    }

    public func getEncryptionInfo() throws -> FolderEncryptionInfo {
        if let cachedInfo {
            return cachedInfo
        }

        let folder = try datasource.getRoot()

        guard let moc = folder.moc else {
            throw Folder.noMOC()
        }

        return try moc.performAndWait {
            let info = try folder.encrypting()
            self.cachedInfo = info
            return info
        }
    }
}
