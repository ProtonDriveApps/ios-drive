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

import Combine
import CoreData
import Foundation
import PDCore

protocol LocalAlbumListControllerProtocol {
    var updatePublisher: AnyPublisher<[AlbumListing], Never> { get }

    func list(albumTag: AlbumTag?) throws
    func getListings(albumTag: AlbumTag?) throws -> [AlbumListing]
}

final class LocalAlbumListController: LocalAlbumListControllerProtocol {
    private let dependencies: Dependencies
    private var cancellables = Set<AnyCancellable>()
    private var observer: FetchedResultsSectionsController<CoreDataAlbumListing>?
    private let backgroundQueue = DispatchQueue(label: "LocalAlbumsRepository", qos: .userInteractive)
    private let subject = PassthroughSubject<[AlbumListing], Never>()
    var updatePublisher: AnyPublisher<[AlbumListing], Never> {
        subject.eraseToAnyPublisher()
    }

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    /// List album in the database
    /// - Parameter albumTag: nil means all
    func list(albumTag: AlbumTag?) throws {
        cancellables.removeAll()
        let observer = try dependencies.observerFactory.makeObserver(filter: albumTag)
        self.observer = observer
        observer.objectWillChange
            .throttle(for: .milliseconds(250), scheduler: backgroundQueue, latest: true)
            .map { [weak self] _ in
                let list = self?.observer?.getObjects() ?? []
                return self?.mapping(albums: list) ?? []
            }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] list in
                self?.subject.send(list)
            }
            .store(in: &cancellables)
        backgroundQueue.async {
            observer.start()
        }
    }

    func getListings(albumTag: AlbumTag?) throws -> [AlbumListing] {
        let observer = try dependencies.observerFactory.makeObserver(filter: albumTag)
        observer.start()
        let listings = observer.getObjects()
        return mapping(albums: listings)
    }

    private func mapping(albums: [CoreDataAlbumListing]) -> [AlbumListing] {
        return dependencies.managedObjectContext.performAndWait {
            albums.map { album in
                AlbumListing(
                    albumIdentifier: album.albumIdentifier,
                    coverLinkID: album.coverLinkID,
                    photoCount: album.photoCount,
                    shareID: album.shareID,
                    clearName: album.album?.decryptedName
                )
            }
        }
    }
}

extension LocalAlbumListController {
    struct Dependencies {
        let managedObjectContext: NSManagedObjectContext
        let observerFactory: AlbumListObserverFactory
    }
}
