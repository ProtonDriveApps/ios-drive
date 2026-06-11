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
import Foundation

/// PhotosList
/// Is shared component for observing and mapping CoreData photo to domain level objects.
/// The subscription should be configurable by a filter - photo type, album type etc.
protocol PhotosListControllerProtocol: AnyObject {
    var sections: AnyPublisher<[PhotosListSection], Never> { get }
    var isLoading: AnyPublisher<Bool, Never> { get }
    func getIds() -> Set<PhotoId>
    func getListings() -> [PhotoListing]
    func setFilter(_ filter: PhotosListFilter)
    func stopObserving()
}

final class PhotosListController: PhotosListControllerProtocol {
    private let repository: PhotosListRepository
    private let subject = CurrentValueSubject<[PhotosListSection], Never>([])
    private let isLoadingSubject = CurrentValueSubject<Bool, Never>(true)
    private var cancellables = Set<AnyCancellable>()

    var sections: AnyPublisher<[PhotosListSection], Never> {
        subject.eraseToAnyPublisher()
    }

    var isLoading: AnyPublisher<Bool, Never> {
        isLoadingSubject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    init(repository: PhotosListRepository) {
        self.repository = repository
        repository.updatePublisher
            .sink { [weak self] section in
                self?.isLoadingSubject.send(false)
                self?.subject.send(section)
            }
            .store(in: &cancellables)
    }

    func getIds() -> Set<PhotoId> {
        Set(getListings().map(\.id))
    }

    func getListings() -> [PhotoListing] {
        subject.value.flatMap(\.photos)
    }

    func setFilter(_ filter: PhotosListFilter) {
        isLoadingSubject.send(true)
        repository.setFilter(filter)
    }

    func stopObserving() {
        repository.stopObserving()
    }
}
