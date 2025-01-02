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
import Foundation
import PDCore

protocol PhotoContentLoadStrategyProtocol {
    func loadStrategy(of id: NodeIdentifier) throws -> PhotoContentLoadStrategy.Strategy
}

extension PhotoContentLoadStrategy {
    enum Strategy {
        /// Main asset still uploading
        case waitingForMainAssetUploaded
        /// Main asset uploaded; children still uploading
        case returnMainAssetDuringChildrenUpload
        /// All assets are uploaded, but uncached assets exceed the allowed number
        case returnMainAssetAndDownloadChildren
        case allAssetsAvailable
    }
}

final class PhotoContentLoadStrategy: PhotoContentLoadStrategyProtocol {
    private let fetchResource: PhotoFetchResourceProtocol
    private let managedObjectContext: NSManagedObjectContext
    
    init(fetchResource: PhotoFetchResourceProtocol, managedObjectContext: NSManagedObjectContext) {
        self.fetchResource = fetchResource
        self.managedObjectContext = managedObjectContext
    }
    
    func loadStrategy(of id: NodeIdentifier) throws -> Strategy {
        let mainPhoto = try fetchResource.fetchPhoto(with: id, context: managedObjectContext)
        guard isUploaded(mainPhoto: mainPhoto) else { return .waitingForMainAssetUploaded  }
        
        let (areAllChildrenUploaded, uncachedNum) = getChildrenInfo(from: mainPhoto)
        if areAllChildrenUploaded {
            if uncachedNum == 0 {
                return .allAssetsAvailable
            } else {
                // There are some uncached children
                // return main photo first to have better UX 
                return .returnMainAssetAndDownloadChildren
            }
        } else {
            return .returnMainAssetDuringChildrenUpload
        }
    }
    
    private func isUploaded(mainPhoto: Photo) -> Bool {
        managedObjectContext.performAndWait {
            mainPhoto.state == .active
        }
    }
    
    private func getChildrenInfo(from mainPhoto: Photo) -> (Bool, Int) {
        managedObjectContext.performAndWait {
            let children = Array(mainPhoto.children)
            let areUploaded = children.allSatisfy { $0.state == .active }
            let uncachedNum = children.filter { !$0.photoRevision.blocksAreValid() }.count
            return (areUploaded, uncachedNum)
        }
    }
    
    private func isCached(photo: Photo) -> Bool {
        return photo.moc?.performAndWait {
            photo.photoRevision.blocksAreValid()
        } ?? false
    }
}
