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
    var content: AnyPublisher<FileContent, Error> { get }
    func execute(with id: NodeIdentifier)
    func clear()
}

final class LocalFileContentController: FileContentController {
    private let resource: FileContentResource
    private let storageResource: LocalStorageResource
    private let subject = PassthroughSubject<FileContent, Error>()
    private var lastFileContent: FileContent?
    private var cancellables = Set<AnyCancellable>()

    var content: AnyPublisher<FileContent, Error> {
        subject.eraseToAnyPublisher()
    }

    init(resource: FileContentResource, storageResource: LocalStorageResource) {
        self.resource = resource
        self.storageResource = storageResource
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        resource.result
            .sink { [weak self] result in
                if case let .failure(error) = result {
                    self?.subject.send(completion: .failure(error))
                }
            } receiveValue: { [weak self] content in
                self?.lastFileContent = content
                self?.subject.send(content)
            }
            .store(in: &cancellables)

    }

    func execute(with id: NodeIdentifier) {
        resource.execute(with: id)
    }

    func clear() {
        resource.cancel()
        guard let lastFileContent else { return }
        try? storageResource.delete(at: lastFileContent.url)
        lastFileContent.childrenURLs.forEach { try? storageResource.delete(at: $0) }
    }
}
