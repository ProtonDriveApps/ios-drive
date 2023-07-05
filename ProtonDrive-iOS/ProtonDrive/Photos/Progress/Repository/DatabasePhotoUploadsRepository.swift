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
import Foundation
import PDCore

final class DatabasePhotoUploadsRepository: PhotoUploadsRepository {
    private let observer: FetchedResultsControllerObserver<Photo>
    private var cancellables = Set<AnyCancellable>()
    private let subject = PassthroughSubject<Int, Never>()

    var count: AnyPublisher<Int, Never> {
        subject.eraseToAnyPublisher()
    }

    init(observer: FetchedResultsControllerObserver<Photo>) {
        self.observer = observer
        subscribeToUpdates()
    }

    func getInitialCount() -> Int {
        observer.cache.count
    }

    private func subscribeToUpdates() {
        observer.photos
            .map { photos in
                photos.count
            }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] count in
                self?.subject.send(count)
            }
            .store(in: &cancellables)
    }
}
