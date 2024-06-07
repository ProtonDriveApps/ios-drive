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
import PDCore

protocol PhotosUploadingCountRepository {
    var count: AnyPublisher<Int, Never> { get }
}

final class CoreDataPhotosUploadingCountRepository: PhotosUploadingCountRepository {
    private let observer: FetchedResultsControllerObserver<Photo>
    private let subject = PassthroughSubject<Int, Never>()
    private var cancellables = Set<AnyCancellable>()

    var count: AnyPublisher<Int, Never> {
        subject
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    init(observer: FetchedResultsControllerObserver<Photo>) {
        self.observer = observer
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        observer
            .getPublisher()
            .map { photos in
                photos.count
            }
            .removeDuplicates()
            .sink { [weak self] count in
                self?.subject.send(count)
            }
            .store(in: &cancellables)
    }
}
