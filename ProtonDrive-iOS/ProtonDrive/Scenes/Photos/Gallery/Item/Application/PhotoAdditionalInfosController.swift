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

protocol PhotoAdditionalInfosController {
    var items: AnyPublisher<PhotoAdditionalInfos, Never> { get }
    func load(id: PhotoId)
}

final class ConcretePhotoAdditionalInfosController: PhotoAdditionalInfosController {
    private let subject = CurrentValueSubject<PhotoAdditionalInfos, Never>([:])
    private let repository: PhotoAdditionalInfoRepository
    private var cancellables = Set<AnyCancellable>()

    var items: AnyPublisher<PhotoAdditionalInfos, Never> {
        subject.eraseToAnyPublisher()
    }

    init(repository: PhotoAdditionalInfoRepository) {
        self.repository = repository
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        repository.info
            .sink { [weak self] info in
                guard let self else { return }
                var values = self.subject.value
                values[info.id] = info
                self.subject.send(values)
            }
            .store(in: &cancellables)
    }

    func load(id: PhotoId) {
        repository.load(id: id)
    }
}
