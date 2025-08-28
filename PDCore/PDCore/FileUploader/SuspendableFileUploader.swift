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
import Combine
import CoreData

public final class SuspendableFileUploader: FileUploader, NetworkConstrained {
    private var suspCancellables = Set<AnyCancellable>()

    var networkMonitor: NetworkStateResource = MonitoringNetworkStateResource()
    var isNetworkReachable = true

    weak var fileUploader: FileUploader?
    weak var progress: Progress?

    public required init(uploader: FileUploader, progress: Progress?) {
        self.fileUploader = uploader
        self.progress = progress
        self.networkMonitor.execute()
        super.init(fileUploadFactory: uploader.fileUploadFactory,
                   filecleaner: uploader.filecleaner,
                   moc: uploader.moc, dispatchQueue: uploader.dispatchQueue)
        self.setupNetworkMonitoring()
    }

    private func setupNetworkMonitoring() {
        networkMonitor.state
            .removeDuplicates()
            .sink { [weak self] state in
                switch state {
                case .reachable:
                    self?.isNetworkReachable = true
                    self?.retryQueuedUploadOperations()
                case .unreachable:
                    self?.isNetworkReachable = false
                    self?.handleNetworkUnreachable()
                }
            }
            .store(in: &suspCancellables)
    }

    private func retryQueuedUploadOperations() {
        resumeAllOperations()
    }

    private func handleNetworkUnreachable() {
        suspendAllOperations()
    }

    public func invalidateOperations() {
        if isNetworkReachable {
            cancelAllOperations()
        } else {
            Log.info("Pause Uploads", domain: .uploader)
            pauseAllUploads()
        }
    }

    @discardableResult
    override public func uploadFile(_ file: File, completion: @escaping OnUploadCompletion) throws -> Progress {
        return try moc.performAndWait {
            let file = file.in(moc: self.moc)
            let draft = try FileDraft.extract(from: file)
            let uploadID = draft.uploadID
            let clientUID = file.clientUID

            let shareID = file.shareId
            guard let parentID = file.parentNode?.id else {
                throw file.invalidState("The file doesn't have a parentID")
            }

            let operation = self.fileUploadFactory.getOperations(for: draft) { [weak self] result in
                guard let self else { return }

                let handleFailedUpload: ((Error) -> Void) = { [weak self] error in
                    guard let self else { return }

                    let error = self.mapDefaultError(error)
                    NotificationCenter.default.post(name: .didFindIssueOnFileUpload, object: nil)
                    Log.error("SuspendableFileUploader uploadfile error", error: error, domain: .uploader)
                    self.handleUploadError(error, for: uploadID)
                    completion(.failure(error))
                    
                    if uploadFailureShouldNotBeReported(error: error) {
                        return
                    }
                    
                    uploadSuccessRateMonitor.incrementFailure(
                        identifier: file.identifier,
                        shareType: .main,
                        initiator: .background
                    )
                }

                switch result {
                case .success(let file):
                    completion(.success(file))
                    uploadSuccessRateMonitor.incrementSuccess(
                        identifier: file.identifier,
                        shareType: .main,
                        initiator: .background
                    )

                // File or draft already exists
                case .failure(let error as ResponseError):
                    if let linkID = error.linkIDOfPreviousFailedUploadFromCurrentClient(clientUID: clientUID) {
                        self.filecleaner.deleteUploadingFile(linkId: linkID, parentId: parentID, shareId: shareID, completion: { [weak self] result in
                            guard let self else { return }

                            switch result {
                            case .success:
                                do {
                                    try self.uploadFile(file, completion: completion)
                                } catch let error {
                                    handleFailedUpload(error)
                                }
                            case .failure(let error):
                                handleFailedUpload(error)
                            }
                        })
                    } else {
                        handleFailedUpload(error)
                    }
                case .failure(let error):
                    handleFailedUpload(error)
                }
            }

            draft.file.changeUploadingState(to: .uploading)
            addOperation(operation)
            let operationProgress = operation.progress
            operationProgress.kind = .file
            operationProgress.fileOperationKind = .uploading
            guard let progress else { return operationProgress }
            operationProgress.totalUnitsOfWork = progress.totalUnitsOfWork
            progress.addChild(operationProgress, pending: progress.totalUnitsOfWork)
            return operationProgress
        }
    }
    
    private func uploadFailureShouldNotBeReported(error: Error) -> Bool {
        if error.isNetworkIssueError{
            return true
        }
        
        if error.responseCode == nil {
            return false
        }
        
        if let responseCode = ResponseCode(rawValue: error.responseCode!) {
            switch responseCode {
            case .tooManyChildren, .insufficientQuota, .insufficientSpace:
                return true
            }
        } 
        
        return false
    }

    private func handleUploadError(_ error: Error, for uploadID: UUID) {
        if self.isNetworkReachable {
            self.cancelOperation(id: uploadID)
        } else {
            self.suspendAllOperations()
        }
    }

    override public func deleteUploadingFile(_ file: File, error: PhotosFailureUserError? = nil) {
        fileUploader?.deleteUploadingFile(file, error: error)
    }
}
