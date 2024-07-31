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

import Combine
import CoreData

public class FileUploader: OperationProcessor<FileUploaderOperation>, ErrorController {

    let fileUploadFactory: FileUploadOperationsProvider
    let filecleaner: CloudFileCleaner
    let moc: NSManagedObjectContext
    var isEnabled = true {
        didSet { Log.info("\(type(of: self)) isEnabled will become \(isEnabled)", domain: .uploader) }
    }
    var didSignOut = false {
        didSet { Log.info("\(type(of: self)) didSignOut will become \(didSignOut)", domain: .uploader) }
    }
    let dispatchQueue: DispatchQueue

    let errorStream: PassthroughSubject<Error, Never> = PassthroughSubject()
    private var cancellables = Set<AnyCancellable>()

    public var errorPublisher: AnyPublisher<Error, Never> {
        errorStream
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    public init(
        concurrentOperations: Int = Constants.maxCountOfConcurrentFileUploaderOperations,
        fileUploadFactory: FileUploadOperationsProvider,
        filecleaner: CloudFileCleaner,
        moc: NSManagedObjectContext,
        dispatchQueue: DispatchQueue? = nil
    ) {
        self.fileUploadFactory = fileUploadFactory
        self.filecleaner = filecleaner
        self.moc = moc
        self.dispatchQueue = dispatchQueue ?? DispatchQueue.global(qos: .userInitiated)
        super.init(queue: OperationQueue(maxConcurrentOperation: concurrentOperations, underlyingQueue: dispatchQueue))
    }

    public func upload(_ file: File, completion: @escaping OnUploadCompletion = { _ in }) {
        fatalError("Should not be used.")
    }

    @discardableResult
    public func uploadFile(_ file: File, completion: @escaping OnUploadCompletion) throws -> Progress {
        return try moc.performAndWait {
            let file = file.in(moc: self.moc)
            let draft = try FileDraft.extract(from: file)
            let uploadID = draft.uploadID
            let clientUID = file.clientUID

            let shareID = file.shareID
            guard let parentID = file.parentLink?.id else {
                throw file.invalidState("The file doesn't have a parentID")
            }

            let operation = self.fileUploadFactory.getOperations(for: draft) { [weak self] result in
                guard let self else { return }

                let handleFailedUpload: ((Error) -> Void) = { [weak self] error in
                    guard let self else { return }

                    let error = self.mapDefaultError(error)
                    NotificationCenter.default.post(name: .didFindIssueOnFileUpload, object: nil)
                    Log.error("Upload error: \(error.localizedDescription)", domain: .uploader)
                    self.cancelOperation(id: uploadID)
                    completion(.failure(error))
                }

                switch result {
                case .success(let file):
                    completion(.success(file))

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
            return operation.progress
        }
    }

    func canUpload(_ file: File) -> Bool {
        guard let id = file.uploadID,
              !file.isUploading,
              isEnabled,
              getProcessingOperation(with: id) == nil else {
            return false
        }
        return true
    }
    
    func canUploadWithError(_ file: File) throws {
        guard !file.isUploading else {
            throw CanUploadError.isUploading
        }

        guard let id = file.uploadID else {
            throw CanUploadError.noUploadID
        }

        guard getProcessingOperation(with: id) == nil else {
            throw CanUploadError.processingOperationAlreadyExists
        }

        guard let state = file.state, !file.committedStates.contains(state) else {
            throw CanUploadError.fileAlreadyUploaded
        }

        guard isEnabled else {
            throw CanUploadError.uploaderNotEnabled
        }
    }
    
    enum CanUploadError: Error, LocalizedError {
        case noUploadID
        case isUploading
        case uploaderNotEnabled
        case processingOperationAlreadyExists
        case fileAlreadyUploaded
    }

    func pauseFileUpload(id: UUID) {
        getProcessingOperation(with: id)?.pauseUpload()
    }

    public func deleteUploadingFile(_ file: File) {
        moc.perform { [weak self] in
            guard let self else { return }

            let file = file.in(moc: self.moc)
            self.performDeletionOfUploadingFileOutsideMOC(file)
        }
    }
    
    public func performDeletionOfUploadingFileOutsideMOC(_ file: File) {

        guard let uploadID = file.uploadID,
              let parentId = file.parentLink?.id else {
            Log.info("\(type(of: self)).deleteUploadingFile: no uploadID or parentID ❌", domain: .uploader)
            return
        }

        self.getProcessingOperation(with: uploadID)?.cancel()

        // Handle create new revision when avaiable
        if file.isCreatingFileDraft() || file.isEncryptingRevision() {
            Log.info("\(type(of: self)).deleteUploadingFile: deleting local File/Photo state:encryptingRevision, UUID: \(uploadID)", domain: .uploader)
            file.delete()
        } else if file.isUploadingRevision() || file.isCommitingRevision() {
            if file is Photo {
                let fileID = file.id
                let parentID = parentId
                let shareID = file.shareID
                Task {
                    do {
                        Log.info("\(type(of: self)).deleteUploadingFile: deleting remote Photo state: .creatingFileDraft, .uploadingRevision, .commitingRevision, UUID: \(uploadID)", domain: .uploader)
                        try await self.filecleaner.deleteUploadingFile(shareId: shareID, parentId: parentID, linkId: fileID)
                        file.delete()
                    } catch let responseError as ResponseError {
                        Log.error("\(String(describing: responseError.errorDescription)), UUID: \(uploadID)", domain: .uploader)
                        file.delete()
                    } catch CloudFileCleanerError.fileIsNotADraft {
                        Log.error("\(CloudFileCleanerError.fileIsNotADraft)), UUID: \(uploadID)", domain: .uploader)
                    } catch {
                        Log.error("\(String(describing: error.localizedDescription)), UUID: \(uploadID)", domain: .uploader)
                        file.delete()
                    }
                }
            } else {
                Log.info("\(type(of: self)).deleteUploadingFile: deleting remote File state: .creatingFileDraft, .uploadingRevision, .commitingRevision, UUID: \(uploadID)", domain: .uploader)
                self.filecleaner.deleteUploadingFile(linkId: file.id, parentId: parentId, shareId: file.shareID, completion: { _ in
                    // The result is ignored because deleting file draft is not strictly required.
                    // * the file draft will be cleared after 4 hours by backend's collector,
                    // * during the initial file upload, if the file draft already exists and its uploadClientUID
                    //   matches the new file, we will delete the file draft, see `uploadFile` method
                })
                file.delete()
            }
        } else {
            Log.info("\(type(of: self)).deleteUploadingFile: unknown state ❌, UUID: \(uploadID)", domain: .uploader)
        }
    }

    public func pauseAllUploads() {
        NotificationCenter.default.post(name: .didInterruptOnFileUpload, object: nil)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.getAllScheduledOperations().forEach { $0.interrupt() }
        }
    }

    func handleDefaultError(_ error: Error, completion: @escaping OnUploadCompletion) {
        guard !didSignOut else { return }

        let error = mapDefaultError(error)
        NotificationCenter.default.post(name: .didFindIssueOnFileUpload, object: nil)
        Log.error(error.localizedDescription, domain: .uploader)
        errorStream.send(error)
        completion(.failure(error))
    }

    func mapDefaultError(_ error: Error) -> Error {
        if let error = error as? ResponseError, error.isVerificationError {
            return FileUploaderError.verificationError(error)
        } else {
            return error
        }
    }

}

extension FileUploader: WorkingNotifier {
    public var isWorkingPublisher: AnyPublisher<Bool, Never> {
        processingQueue.publisher(for: \.operationCount)
            .map { $0 != 0 }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
