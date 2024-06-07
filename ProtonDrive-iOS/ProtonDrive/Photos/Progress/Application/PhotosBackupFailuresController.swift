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
import PDCore

protocol PhotosBackupFailuresController {
    var count: AnyPublisher<Int, Never> { get }
}

final class LocalPhotosBackupFailuresController: PhotosBackupFailuresController {
    private let cleanedUploadingStore: DeletedPhotosIdentifierStoreResource
    private let subject = CurrentValueSubject<Int, Never>(0)
    private var cancellables = Set<AnyCancellable>()

    var count: AnyPublisher<Int, Never> {
        subject.eraseToAnyPublisher()
    }

    init(cleanedUploadingStore: DeletedPhotosIdentifierStoreResource) {
        self.cleanedUploadingStore = cleanedUploadingStore
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        cleanedUploadingStore.count
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] count in
                self?.subject.send(count)
            }
            .store(in: &cancellables)
    }
}
