// Copyright (c) 2026 Proton AG
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
import PDCore

final class NodeDownloadedResource: Sendable {
    private let managedObjectContext: NSManagedObjectContext
    private var identifiersInProgress = Set<AnyVolumeIdentifier>()
    private var subject = CurrentValueSubject<[AnyVolumeIdentifier: Bool], Never>([:])

    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
    }

    /// Returns publisher 
    func startLoading(for id: AnyVolumeIdentifier) -> AnyPublisher<Bool, Never> {
        if !identifiersInProgress.contains(id) {
            loadValue(id: id)
        }
        return subject
            .compactMap { $0[id] }
            .eraseToAnyPublisher()
    }

    private func loadValue(id: AnyVolumeIdentifier) {
        Task { [weak self] in
            let value = await self?.getIsDownloaded(id: id)
            await MainActor.run {
                guard let value else { return }
                self?.processResult(id: id, value: value)
            }
        }
        identifiersInProgress.insert(id)
    }

    private func getIsDownloaded(id: AnyVolumeIdentifier) async -> Bool {
        return await managedObjectContext.perform { [managedObjectContext] in
            guard let node = CoreDataNode.fetch(identifier: id, allowSubclasses: true, in: managedObjectContext) else {
                return false
            }

            return node.isDownloaded
        }
    }

    @MainActor
    private func processResult(id: AnyVolumeIdentifier, value: Bool) {
        var dictionary = subject.value
        dictionary[id] = value
        identifiersInProgress.remove(id)
        self.subject.send(dictionary)
    }
}
