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

protocol PhotoAdditionalInfoController {
    var info: AnyPublisher<PhotoAdditionalInfo, Never> { get }
    func subscribeToUpdates()
    func load()
}

final class ConcretePhotoAdditionalInfoController: PhotoAdditionalInfoController {
    private let id: PhotoId
    private let subject = CurrentValueSubject<PhotoAdditionalInfo?, Never>(nil)
    private let controller: PhotoAdditionalInfosController
    private var cancellables = Set<AnyCancellable>()

    var info: AnyPublisher<PhotoAdditionalInfo, Never> {
        subject.compactMap { $0 }
            .eraseToAnyPublisher()
    }

    init(id: PhotoId, controller: PhotoAdditionalInfosController) {
        self.id = id
        self.controller = controller
    }

    func subscribeToUpdates() {
        cancellables.removeAll()
        controller.items
            .sink { [weak self] items in
                guard let self else { return }
                guard let item = items[self.id] else { return }
                self.subject.send(item)
            }
            .store(in: &cancellables)
    }

    func load() {
        guard subject.value == nil else {
            return
        }
        controller.load(id: id)
    }
}
