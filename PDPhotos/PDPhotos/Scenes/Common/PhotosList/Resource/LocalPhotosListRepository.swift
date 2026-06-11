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
import CoreData
import PDCore

final class LocalPhotosListRepository: PhotosListRepository {
    typealias Observer = CompoundFetchedResultsController<CoreDataPhotoListing, CoreDataPhoto>

    private let observerFactory: PhotosListObserverFactory
    private let configuration: PhotosListConfiguration
    private let managedObjectContext: NSManagedObjectContext
    private var filter: PhotosListFilter?
    private var observer: Observer?
    private let offlineAvailableResource: OfflineAvailableResource
    private let mappingResource: PhotoListingsMappingResourceProtocol
    private var cancellables = Set<AnyCancellable>()
    private let subject = PassthroughSubject<[PhotosListSection], Never>()
    private let backgroundQueue = DispatchQueue(label: "LocalPhotosRepository", qos: .userInteractive)
    @ThreadSafe private var isObserving = true

    var updatePublisher: AnyPublisher<[PhotosListSection], Never> {
        subject.eraseToAnyPublisher()
    }

    init(
        configuration: PhotosListConfiguration,
        observerFactory: PhotosListObserverFactory,
        managedObjectContext: NSManagedObjectContext,
        offlineAvailableResource: OfflineAvailableResource,
        mappingResource: PhotoListingsMappingResourceProtocol
    ) {
        self.configuration = configuration
        self.observerFactory = observerFactory
        self.managedObjectContext = managedObjectContext
        self.offlineAvailableResource = offlineAvailableResource
        self.mappingResource = mappingResource
        setupObserver()
    }

    func stopObserving() {
        isObserving = false
        observer = nil
    }

    func setFilter(_ filter: PhotosListFilter) {
        guard self.filter != filter else {
            return
        }
        self.filter = filter
        setupObserver()
    }

    private func setupObserver() {
        cancellables.removeAll()
        let observer = observerFactory.makeListingAndMetadataObserver(
            configuration: configuration,
            filter: filter,
            managedObjectContext: managedObjectContext
        )
        self.observer = observer
        subscribeToUpdates(observer: observer, configuration: configuration, filter: filter)
        backgroundQueue.async {
            observer.start()
        }
    }

    private func subscribeToUpdates(observer: Observer, configuration: PhotosListConfiguration, filter: PhotosListFilter?) {
        Publishers.CombineLatest(observer.objectWillChange, offlineAvailableResource.inProgressIds)
            .throttle(for: .seconds(1), scheduler: backgroundQueue, latest: true)
            .map { [weak self] update -> [PhotosListSection] in
                guard let self = self, isObserving else { return [] }
                let start = CFAbsoluteTimeGetCurrent()
                let sections = self.makeSections(observer: observer, configuration: configuration, downloadingIds: update.1, filter: filter)
                let end = CFAbsoluteTimeGetCurrent()
                let mappingDurationInMilliseconds = (end - start) * 1000
                if mappingDurationInMilliseconds > 500 {
                    Log.warning("Mapping of photo sections took \(mappingDurationInMilliseconds)ms.", domain: .photosUI)
                }
                return sections
            }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sections in
                self?.subject.send(sections)
            }
            .store(in: &cancellables)
    }

    private func makeSections(observer: Observer, configuration: PhotosListConfiguration, downloadingIds: PhotoIdsSet, filter: PhotosListFilter?) -> [PhotosListSection] {
        if configuration.isSingleSection {
            let listings = observer.getObjects()
            return managedObjectContext.performAndWait {
                return self.mappingResource.mapSections(listings: [listings], downloadingIds: downloadingIds)
            }
        } else {
            let sections = observer.getSections()
            return managedObjectContext.performAndWait {
                return self.mappingResource.mapSections(listings: sections, downloadingIds: downloadingIds)
            }
        }
    }
}
