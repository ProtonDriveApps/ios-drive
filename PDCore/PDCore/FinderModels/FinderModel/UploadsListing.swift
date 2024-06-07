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

public struct URLContent {
    public let url: URL
    public let size: Int

    public init(_ url: URL, _ size: Int) {
        self.url = url
        self.size = size
    }
}

extension UploadsListing {
    public func childrenUploading() -> AnyPublisher<([File], [FileUploader.OperationID: FileUploader.CurrentProgress]), Error> {
        childrenUploadingObserver.objectWillChange
            .setFailureType(to: Error.self)
            .combineLatest(tower.fileUploader.progressPublisher())
            .throttle(for: 0.02, scheduler: DispatchQueue.main, latest: true)
            .map { [unowned self] (_, progresses) in
                return (self.childrenUploadingObserver.fetchedObjects, progresses)
            }
            .removeDuplicates(by: { previous, current in
                return previous.0 == current.0 && previous.1 == current.1
            })
            .eraseToAnyPublisher()
    }
    
    public func loadUploadsFromCache() {
        self.childrenUploadingObserver.start()
    }
    
    public func pauseUpload(file: File) {
        guard let uploadID = file.uploadID else { return }
        tower.fileUploader.pauseFileUpload(id: uploadID)
    }
    
    public func cancelUpload(file: File) {
        tower.fileUploader.deleteUploadingFile(file)
    }
    
    public func uploadFile(_ content: URLContent, to folder: Folder) throws {
        guard let newFile = try? tower.fileImporter.importFile(from: content.url, to: folder),
              content.size == content.url.fileSize else {
            assert(false, "Failed to create File")
            throw URLConsistencyError.urlSizeMismatch
        }

        tower.fileUploader.upload(newFile, completion: { _ in })
    }

    public func restartUpload(node: File) {
        tower.fileUploader.upload(node, completion: { _ in })
    }
}
