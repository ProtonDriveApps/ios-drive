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
import os.log

public enum FileUploaderError: Error {
    case missingOperations
    case insuficientSpace
    case expiredUploadURL
    case expiredFileDraft
}

public class FileUploader: OperationProcessor<MainFileUploaderOperation>, LogObject {

    public static let osLog: OSLog = OSLog(subsystem: "ProtonDrive", category: "FileUploader")

    private let fileUploadFactory: FileUploadOperationsProvider
    private let storage: StorageManager
    let moc: NSManagedObjectContext

    public var queue: OperationQueue {
        processingQueue
    }

    let errorStream: PassthroughSubject<Error, Never> = PassthroughSubject()
    private var cancellables = Set<AnyCancellable>()

    init(
        concurrentOperations: Int = 5,
        fileUploadFactory: FileUploadOperationsProvider,
        storage: StorageManager,
        sessionVault: SessionVault,
        moc: NSManagedObjectContext
    ) {
        self.fileUploadFactory = fileUploadFactory
        self.storage = storage
        self.moc = moc
        super.init(queue: OperationQueue(maxConcurrentOperation: concurrentOperations))

        sessionVault
            .objectWillChange
            .compactMap(sessionVault.getUserInfo)
            .map(\.availableStorage)
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] in
                restartWaitingOperations(availableStorage: $0)
            }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: .restartUploadExpired)
            .delay(for: 0.5, scheduler: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let file = notification.object as? File else { return }
                self?.upload(file)
            }
            .store(in: &cancellables)
    }

    public func restartOperations() throws {
        let uploading = storage.fetchFilesUploading(moc: storage.mainContext)
        restartFilesUpload(files: uploading)
        if !isProcessingOperations {
            throw FileUploaderError.missingOperations
        }
    }
    
    public func restartInterruptedUploads() {
        let interrupted = storage.fetchFilesInterrupted(moc: storage.mainContext)
        restartFilesUpload(files: interrupted)
    }
    
    private func restartFilesUpload(files: [File]) {
        for file in files {
            self.upload(file)
        }
    }

    public func pause(file: File) {
        guard let uploadID = file.uploadID else { return }
        getProcessingOperation(with: uploadID)?.pause()
    }

    public func cancel(uploadID: UUID?) {
        guard let uploadID = uploadID else { return }
        cancelOperation(with: uploadID)
    }

    public func remove(file: File, completion: @escaping (Error?) -> Void) {
        pause(file: file)
        if let url = file.activeRevisionDraft?.uploadableResourceURL {
            cleaupCleartext(at: url)
        }
        file.managedObjectContext!.perform {
            do {
                file.managedObjectContext?.delete(file)
                try file.managedObjectContext?.save()
                completion(nil)
            } catch {
                ConsoleLogger.shared?.log(DriveError(error, "FileUploader"))
                completion(error)
            }
        }
    }

    public func cancelAll() {
        cancellAllOperations()
    }

    public func pauseAllUploads() {
        NotificationCenter.default.post(name: .didInterruptOnFileUpload, object: nil)
        getAllScheduledOperations().forEach { $0.interrupt() }
    }
    
    func cleaupCleartext(at url: URL) {
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        } catch {
            ConsoleLogger.shared?.log(DriveError(error, "FileUploader"))
            assertionFailure("Could not remove cleartext file: " + error.localizedDescription)
        }
    }
}

extension FileUploader {
    private func restartWaitingOperations(availableStorage: Int) {
        var storageLeft = availableStorage
        let runningOperationsIDs = Set(getAllScheduledOperations().map(\.id))
        let waiting = storage.fetchWaiting(maxSize: availableStorage, moc: storage.mainContext)
            .filter { file in
                guard let uploadID = file.uploadID else { return false }
                return !runningOperationsIDs.contains(uploadID)
            }

        ConsoleLogger.shared?.log("Free cloud storage \(availableStorage) found, will attempt to restart \(waiting.count) waiting uploads", osLogType: FileUploader.self)

        for file in waiting {
            guard storageLeft > 0 else { break }
            file.managedObjectContext?.performAndWait {
                ConsoleLogger.shared?.log("Attempt to restart waiting upload with size \(file.size)", osLogType: FileUploader.self)
                storageLeft -= file.size
                self.upload(file) { [weak self] result in
                    switch result {
                    case .success:
                        break
                    case .failure(let error):
                        self?.errorStream.send(error)
                        ConsoleLogger.shared?.log(DriveError(error, "FileUploader"))
                        self?.cancel(uploadID: file.uploadID)
                    }
                }
            }
        }
    }
}

extension FileUploader {
    
    @discardableResult
    public func upload(_ file: File, completion: @escaping OnUploadCompletion = { _ in }) -> any UploadOperation {
        return moc.performAndWait {
            let file = file.in(moc: moc)
            let draft = FileDraft.extract(from: file, moc: moc)
            let uploadID = draft.uploadID
            
            let operation = fileUploadFactory.getOperations(for: draft) { [weak self] result in
                switch result {
                case .success(let file):
                    completion(.success(file))
                case .failure(let error):
                    NotificationCenter.default.post(name: .didFindIssueOnFileUpload, object: nil)
                    ConsoleLogger.shared?.log(DriveError(error, "FileUploader"))
                    
                    self?.cancel(uploadID: uploadID)
                    self?.handleError(error, file: file)
                    completion(.failure(error))
                }
            }
            draft.file.changeState(to: .uploading)
            addOperation(operation)
            return operation
        }
    }

    private func handleError(_ error: Error, file: File) {
        if let fileUploadError = (error as? ResponseError)?.asFileUploadError {
            switch fileUploadError {
            case .expiredUploadURL:
                setExpiredUploadURLsForRevisionIn(file)

            case .expiredFileDraft:
                errorStream.send(fileUploadError)
                /*
                 Call:
                 setExpiredRevisionDraft(file)
                 when the BE does not send delete events for drafts anymore
                 */

            default:
                errorStream.send(fileUploadError)
            }

        } else {
            errorStream.send(error)
        }

    }

    private func setExpiredUploadURLsForRevisionIn(_ file: File) {
        guard let moc = file.moc else { return }

        moc.performAndWait {
            file.state = .paused
            file.activeRevisionDraft?.uploadState = .encrypted
            file.activeRevisionDraft?.blocks.compactMap(\.asUploadBlock).filter { !$0.isUploaded }.forEach { $0.unsetUploadableState() }
            file.activeRevisionDraft?.thumbnails.forEach { $0.unsetUploadedState() }
            try? moc.saveOrRollback()
        }
        NotificationCenter.default.post(name: .restartUploadExpired, object: file)
    }

    private func setExpiredRevisionDraft(_ file: File) {
        guard let moc = file.moc else { return }

        moc.performAndWait {
            file.state = .paused

            let uploadID = UUID()

            file.uploadID = uploadID
            file.id = uploadID.uuidString
            file.clientUID = uploadID.uuidString
            file.activeRevisionDraft?.id = uploadID.uuidString
            file.activeRevisionDraft?.unsetUploadedState()

            try? moc.saveOrRollback()
        }
        NotificationCenter.default.post(name: .restartUploadExpired, object: file)
    }
}

extension ResponseError {
    private var noSpaceOnCloud: Int { 200002 }
    private var expiredResource: Int { 2501 }

    var asFileUploadError: FileUploaderError? {
        if httpCode == 422, code == expiredResource {
            if (self.underlyingError as? FileUploaderError) == .expiredUploadURL {
                return .expiredUploadURL
            } else {
                return .expiredFileDraft
            }
        } else if code == noSpaceOnCloud {
            return .insuficientSpace
        } else {
            return nil
        }
    }
}
