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

protocol FileContentController {
    var url: AnyPublisher<URL, Never> { get }
    func execute(with id: NodeIdentifier)
}

final class LocalFileContentController: FileContentController {
    private let resource: FileContentResource
    private let subject = PassthroughSubject<URL, Never>()
    private var cancellables = Set<AnyCancellable>()

    var url: AnyPublisher<URL, Never> {
        subject.eraseToAnyPublisher()
    }

    init(resource: FileContentResource) {
        self.resource = resource
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        resource.result
            .sink { error in
                // TODO: next MR, handle error
            } receiveValue: { [weak self] url in
                self?.subject.send(url)
            }
            .store(in: &cancellables)

    }

    func execute(with id: NodeIdentifier) {
        resource.execute(with: id)
    }
}
