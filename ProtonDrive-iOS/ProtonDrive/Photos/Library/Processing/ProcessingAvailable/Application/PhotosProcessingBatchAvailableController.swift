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
import PDCore

protocol PhotosProcessingBatchAvailableController {
    var isNextBatchPossible: AnyPublisher<Bool, Never> { get }
}

final class ConcretePhotosProcessingBatchAvailableController: PhotosProcessingBatchAvailableController {
    private let repository: PhotosUploadingCountRepository
    private var subject = CurrentValueSubject<Bool, Never>(true)
    private var cancellables = Set<AnyCancellable>()

    var isNextBatchPossible: AnyPublisher<Bool, Never> {
        subject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    init(repository: PhotosUploadingCountRepository) {
        self.repository = repository
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        repository.count
            .map { count in
                Log.info("PhotosProcessingBatchAvailableController count dropped to: \(count)", domain: .photosProcessing)
                return count < Constants.photosLibraryProcessingBatchSize / 2
            }
            .removeDuplicates()
            .sink { [weak self] isPossible in
                Log.info("PhotosProcessingBatchAvailableController isPossible: \(isPossible)", domain: .photosProcessing)
                self?.subject.send(isPossible)
            }
            .store(in: &cancellables)
    }
}
