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
import CoreData

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
    @MainActor
    public func childrenUploading() -> AnyPublisher<([File], [UUID: Progress]), Error> {
        return childrenUploadingObserver.objectWillChange
            .setFailureType(to: Error.self)
            .combineLatest(sdkProgressPublisher())
            .throttle(for: 0.02, scheduler: DispatchQueue.main, latest: true)
            .map { [unowned self] (_, sdkProgresses) in
                return (self.childrenUploadingObserver.fetchedObjects, sdkProgresses)
            }
            .removeDuplicates(by: { previous, current in
                return previous.0 == current.0 && previous.1 == current.1
            })
            .eraseToAnyPublisher()
    }

    @MainActor
    func sdkProgressPublisher() -> AnyPublisher<[UUID: Progress], Error> {
        let sdkFileUploader = tower.sdkObjects.fileUploader
        return sdkFileUploader.progresses
                .setFailureType(to: Error.self)
                .merge(
                    with: sdkFileUploader.failures
                        .flatMap { _ in Empty<[UUID: Progress], Error>() }
                )
                .eraseToAnyPublisher()
    }

    public func loadUploadsFromCache() {
        self.childrenUploadingObserver.start()
    }
    
    public func pauseUpload(file: File) {
        guard let uploadID = file.uploadID else { return }
        let sdkUploader = tower.sdkObjects.fileUploader
        Task { @MainActor in
            await sdkUploader.pause(identifier: file.genericIdentifier)
        }
    }
    
    public func cancelUpload(file: File) {
        let sdkUploader = tower.sdkObjects.fileUploader
        Task.detached {
            try await sdkUploader.deleteUploadingFile(identifier: file.identifier.any())
        }
    }

    public func restartUpload(node: File) {
        let sdkUploader = tower.sdkObjects.fileUploader
        Task {
            let identifier = node.genericIdentifier
            // Should resume if paused, otherwise starts from scratch
            _ = try await sdkUploader.upload(identifier: identifier)
        }
    }
}
