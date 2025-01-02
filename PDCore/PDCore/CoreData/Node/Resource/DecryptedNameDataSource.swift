// Copyright (c) 2024 Proton AG
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

import CoreData
import Combine

public protocol ProtonDocsDecryptedNameDataSource {
    var decryptedName: AnyPublisher<String, Never> { get }
    func start()
}

enum DecryptedNameDataSourceError: Error {
    case missingNode
}

public final class DatabaseProtonDocsDecryptedNameDataSource: ProtonDocsDecryptedNameDataSource {
    private let observer: FetchedResultsControllerObserver<Node>
    private let dispatchQueue = DispatchQueue(label: "DatabaseDecryptedNameDataSource")
    private let subject = PassthroughSubject<String, Never>()
    private var cancellables = Set<AnyCancellable>()

    public var decryptedName: AnyPublisher<String, Never> {
        subject.eraseToAnyPublisher()
    }

    public init(observer: FetchedResultsControllerObserver<Node>) {
        self.observer = observer
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        observer.getPublisher()
            .receive(on: dispatchQueue)
            .compactMap { nodes in
                guard let node = nodes.first else {
                    return nil
                }
                return node.managedObjectContext?.performAndWait {
                    return node.decryptedName
                }
            }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] decryptedName in
                self?.subject.send(decryptedName)
            }
            .store(in: &cancellables)
    }

    public func start() {
        observer.start()
    }
}
