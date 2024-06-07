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

import Foundation
import PDCore

protocol RemainingPhotoIdentifiersRepository {
    func insert(_ identifiers: PhotoIdentifiers)
    func removeAll()
    func setFilter(_ filter: PhotoLibraryIdentifiersFilter)
    func subtractNext() -> [PhotoIdentifier]
    func getAll() -> [PhotoIdentifier]
    func hasNext() -> Bool
}

final class OrderedRemainingPhotoIdentifiersRepository: RemainingPhotoIdentifiersRepository {
    private var identifiers = PhotoIdentifiers()
    private var filter: PhotoLibraryIdentifiersFilter = .all

    func insert(_ identifiers: PhotoIdentifiers) {
        Log.debug("OrderedRemainingPhotoIdentifiersRepository.insert, ids: \(identifiers.count), allIds: \(self.identifiers.count)", domain: .photosProcessing)
        // New ids might contain modified ids already contained in self.identifiers.
        // By prepending them to the beginning they'll get processed right away and the older ones will be discarded later on.
        self.identifiers.insert(contentsOf: identifiers, at: 0)
    }

    func removeAll() {
        Log.debug("OrderedRemainingPhotoIdentifiersRepository.removeAll", domain: .photosProcessing)
        identifiers.removeAll()
    }

    func setFilter(_ filter: PhotoLibraryIdentifiersFilter) {
        Log.debug("OrderedRemainingPhotoIdentifiersRepository.setFilter: \(filter)", domain: .photosProcessing)
        self.filter = filter
    }

    func subtractNext() -> [PhotoIdentifier] {
        Log.debug("OrderedRemainingPhotoIdentifiersRepository.subtractNext", domain: .photosProcessing)
        switch filter {
        case .all:
            return subtractNonFilteredNextBatch()
        case .small:
            return subtractFilteredNextBatch()
        }
    }

    func getAll() -> [PhotoIdentifier] {
        return identifiers
    }

    func hasNext() -> Bool {
        switch filter {
        case .all:
            return !identifiers.isEmpty
        case .small:
            return identifiers.contains(where: { $0.type == .small })
        }
    }

    private func subtractNonFilteredNextBatch() -> [PhotoIdentifier] {
        let count = min(identifiers.count, Constants.photosLibraryProcessingBatchSize)
        let batch = identifiers.prefix(count)
        identifiers.removeFirst(count)
        return Array(batch)
    }

    private func subtractFilteredNextBatch() -> [PhotoIdentifier] {
        var batch = [PhotoIdentifier]()
        var offsets = IndexSet()
        for (offset, identifier) in identifiers.enumerated() {
            if identifier.type == .small {
                batch.append(identifier)
                offsets.insert(offset)
            }
            if batch.count == Constants.photosLibraryProcessingBatchSize {
                break
            }
        }
        identifiers.remove(atOffsets: offsets)
        return batch
    }
}
