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

import UserNotifications
import Combine

#if canImport(UIKit)
import UIKit
#endif

public protocol UploadsListing: AnyObject {
    var childrenUploadingObserver: FetchedObjectsObserver<File> { get }
    var tower: Tower! { get }
}

public struct UploaderError: Error {
    let url: URL
    let uploadID: UUID
    public let underlyingError: Error

    public init(url: URL, uploadID: UUID, underlyingError: Error) {
        self.url = url
        self.uploadID = uploadID
        self.underlyingError = underlyingError
    }
}

extension UploadsListing {
    typealias UploadError = Uploader.Errors
    public func childrenUploading() -> AnyPublisher<([File], [FileUploader.OperationID: FileUploader.CurrentProgress]), Error> {
        childrenUploadingObserver.objectWillChange
            .setFailureType(to: Error.self)
            .combineLatest(tower.fileUploader.progressPublisher())
            .map { [unowned self] (_, progresses) in
                return (self.childrenUploadingObserver.fetchedObjects, progresses)
            }
            .eraseToAnyPublisher()
    }
    
    public func loadUploadsFromCache() {
        self.childrenUploadingObserver.start()
    }
    
    public func pauseUpload(file: File) {
        tower.fileUploader.pause(file: file)
    }
    
    public func cancelUpload(file: File) {
        tower.fileUploader.remove(file: file) { [weak self, id = file.fileIdentifier] error in
            guard let self = self else { return }

            self.tower.deleteNodesInFolder(nodes: [id.fileID], folder: id.parentID, shareID: id.shareID, completion: { _ in })
        }
    }
    
    public func uploadFile(_ copy: URL, node: Folder) {
        guard let address = self.tower.sessionVault.currentAddress() else {
            assert(false, "No Address in Tower")
            return
        }

        try? tower.fileUploader
            .upload(clearFiles: [copy], parent: node, address: address, completion: { _ in })
    }

    public func restartUpload(node: File) {
        _ = tower.fileUploader.upload(file: node, completion: { _ in })
    }
}
