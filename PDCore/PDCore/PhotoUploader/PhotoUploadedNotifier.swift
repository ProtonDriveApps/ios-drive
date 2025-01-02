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

import Combine
import CoreData
import Foundation

public protocol PhotoUploadedNotifier {
    typealias PhotoID = String
    
    var uploadedNotifier: AnyPublisher<PhotoID, Never> { get }
    
    func uploadCompleted(fileDraft: FileDraft)
}

/// Notify when a photo is uploaded, includes its children contents
public final class ConcretePhotoUploadedNotifier: PhotoUploadedNotifier {
    let moc: NSManagedObjectContext
    var uploadedSubject = PassthroughSubject<PhotoID, Never>()
    public var uploadedNotifier: AnyPublisher<PhotoID, Never> {
        uploadedSubject.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }
    
    public init(moc: NSManagedObjectContext) {
        self.moc = moc
    }
    
    public func uploadCompleted(fileDraft: FileDraft) {
        moc.perform { [weak self] in
            guard let self, let photo = fileDraft.file as? Photo else { return }

            let mainPhoto = photo.parent ?? photo
            if self.isAllContentUploaded(mainPhoto: mainPhoto) {
                uploadedSubject.send(mainPhoto.id)
            }
        }
    }
    
    private func isAllContentUploaded(mainPhoto: Photo) -> Bool {
        let allPhotos = [mainPhoto] + mainPhoto.children
        let notUploadedIdx = allPhotos.firstIndex(where: { $0.state != .active })
        
        return notUploadedIdx == nil
    }

}
