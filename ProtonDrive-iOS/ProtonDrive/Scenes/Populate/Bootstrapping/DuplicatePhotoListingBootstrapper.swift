// Copyright (c) 2025 Proton AG
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
import Foundation
import PDCore
import PDCoreIOS

/// To remove duplicated listings
final class DuplicatePhotoListingBootstrapper: AppBootstrapper {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func bootstrap() async throws {
        try await measure(message: "Remove duplicated photo listings", domain: .applicationBootstrap) {
            try await context.perform { [context] in
                let photoListingsRequest = CoreDataPhotoListing.fetchRequest()
                photoListingsRequest.sortDescriptors = [.init(key: #keyPath(CoreDataPhotoListing.id), ascending: true)]
                let result = try context.fetch(photoListingsRequest)
                let (duplicateListings, duplicatePhotos) = self.getDuplicateListings(from: result)
                if duplicateListings.isEmpty && duplicatePhotos.isEmpty { return }
                Log.error("Duplicate photo listings found in DB", error: nil, domain: .photosUI, context: LogContext("Duplicate listings: \(duplicateListings.count), duplicate photos: \(duplicatePhotos.count)"))
                duplicateListings.forEach { context.delete($0) }
                // Photos need to be deleted too, otherwise event etc are confused and inconsistency of relationship between listing and photo breaks features
                duplicatePhotos.forEach { context.delete($0) }
                try context.saveIfNeeded()
            }
        }
    }

    private func getDuplicateListings(from listings: [CoreDataPhotoListing]) -> (Set<CoreDataPhotoListing>, Set<CoreDataPhoto>) {
        let groups = Dictionary(grouping: listings, by: { $0.listingIdentifier }) // Needs to be unique identifier per stream or album
        var duplicateListings: Set<CoreDataPhotoListing> = []
        var duplicatePhotos: Set<CoreDataPhoto> = []
        for (_, values) in groups {
            guard values.count > 1 else {
                // No duplicate listings, only 1 unique
                continue
            }
            let uniqueItem = values.first(where: { $0.photo != nil }) ?? values[0]
            let duplicates = values.filter { $0 != uniqueItem }
            duplicateListings.formUnion(duplicates)
            duplicatePhotos.formUnion(duplicates.compactMap(\.photo))
        }
        return (duplicateListings, duplicatePhotos)
    }
}
