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

        let completion: OnUploadCompletion = {  [weak self]  result in
            guard let self = self else { return }

            self.onResult(result)
        }

        do {
            try tower.fileUploader
                .upload(clearFiles: [copy], parent: node, address: address, completion: completion)
                .forEach { handleOperationAtBackground($0, id: $0.uploadID.uuidString) }
        } catch {
            completion(.failure(error))
        }
    }

    public func restartUpload(node: File) {
        let completion: OnUploadCompletion = {  [weak self]  result in
            guard let self = self else { return }

            self.onResult(result)
        }

        guard let op = tower.fileUploader.upload(file: node, completion: completion) else { return }

        handleOperationAtBackground(op, id: op.uploadID.uuidString)
    }

    private func onResult(_ result: Result<FileDraft, Error>) {
        switch result {
        case .failure(let error as UploaderError):
            fireWarning(.failure(error.underlyingError), for: error.url.lastPathComponent)

        case .failure(let error):
            fireWarning(.failure(error), for: "Unknown file")

        case .success(let draft):
            fireWarning(.success, for: draft.originalName)
        }
    }
    
    private func fireWarning(_ result: Uploader.Warning, for filename: String) {
        #if DEBUG
        let content = UNMutableNotificationContent()
        content.title = result.title
        content.subtitle = filename
        switch result {
        case .failure(let error):
            content.body = error.localizedDescription
        case .backgroundTaskExpired:
            content.body = "Run out of background execution time"
        case .success: break
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(identifier: filename, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        #endif
    }

    private func handleOperationAtBackground(_ operation: Operation?, id: String) {
        /*
         TODO: We do not need the registration to be done per upload operation, it can be done one general for the entire FileUploader class.
         With this change we lose the ability to fire a warning when the upload fails.
         A better approach to this is to post a notification on the last operation of the upload file chain,
         and subscribe to it from the app itself. This can be done together with DRVIOS-404 that requires us to show the local notification on production too.
         */
    }
}
