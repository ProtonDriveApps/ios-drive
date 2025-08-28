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

import CoreData
import Foundation
import PDCore
import Combine

protocol AlbumRepositoryProtocol {
    var albumID: AnyVolumeIdentifier { get }
    var updatePublisher: AnyPublisher<Album?, Never> { get }

    func start()
}

final class AlbumRepository: AlbumRepositoryProtocol {
    let albumID: AnyVolumeIdentifier
    private let backgroundQueue = DispatchQueue.global(qos: .userInitiated)
    private let managedObjectContext: NSManagedObjectContext
    private var cancellable: AnyCancellable?
    private var observer: FetchedResultsControllerObserver<CoreDataAlbum>?
    private var subject = CurrentValueSubject<Album?, Never>(nil)
    var updatePublisher: AnyPublisher<Album?, Never> {
        subject.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }

    init(albumID: AnyVolumeIdentifier, managedObjectContext: NSManagedObjectContext) {
        self.albumID = albumID
        self.managedObjectContext = managedObjectContext
    }

    func start() {
        let observer = makeObserver()
        self.observer = observer
        cancellable = observer.getPublisher()
            .sink(receiveValue: { [weak self] albums in
                guard let self, let first = albums.first else { return }
                self.subject.send(self.map(album: first))
            })
        // Start can be heavy in case of many objects. Shouldn't be performed on main queue.
        backgroundQueue.async { [weak self] in
            self?.observer?.start()
        }
    }

    private func makeObserver() -> FetchedResultsControllerObserver<CoreDataAlbum> {
        let controller = NSFetchedResultsController(
            fetchRequest: makeRequest(),
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        return FetchedResultsControllerObserver(controller: controller, isAutomaticallyStarted: false)
    }

    private func makeRequest() -> NSFetchRequest<CoreDataAlbum> {
        let fetchRequest = NSFetchRequest<CoreDataAlbum>(entityName: "CoreDataAlbum")
        fetchRequest.fetchLimit = 1
        fetchRequest.predicate = makePredicate()
        fetchRequest.sortDescriptors = [.init(key: #keyPath(CoreDataAlbum.id), ascending: true)]
        return fetchRequest
    }

    private func makePredicate() -> NSPredicate {
        let idPredicate = NSPredicate(format: "%K == %@", #keyPath(CoreDataAlbum.id), albumID.id)
        let volumePredicate = NSPredicate(format: "%K == %@", #keyPath(CoreDataAlbum.volumeID), albumID.volumeID)
        return NSCompoundPredicate(andPredicateWithSubpredicates: [idPredicate, volumePredicate])
    }

    private func map(album: CoreDataAlbum) -> Album {
        managedObjectContext.performAndWait {
            return Album(
                identifier: albumID,
                locked: album.locked,
                coverLinkID: album.coverLinkID,
                lastActivityTime: album.lastActivityTime,
                photoCount: Int(album.photoCount),
                clearName: album.decryptedName,
                nodeHash: album.nodeHash,
                shareID: album.directShares.first?.id,
                role: album.getNodeRole(),
                memberID: album.directShares.first?.members.first?.id // Only has one member
            )
        }
    }
}
