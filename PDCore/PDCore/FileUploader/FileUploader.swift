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

typealias UnitOfWork = Int
typealias OnError = (Error) -> Void
typealias OnUploadSuccess = (FileDraft) -> Void
public typealias OnUploadCompletion = (Result<File, Error>) -> Void

public final class FileUploader: LogObject {
    private enum FileUploaderError: Error {
        case missingOperations
    }
    
    public static let osLog: OSLog = OSLog(subsystem: "ProtonDrive", category: "FileUploader")

    private let fileUploadFactory: FileUploadOperationsProvider
    private let storage: StorageManager
    private let moc: NSManagedObjectContext

    public let queue = OperationQueue(maxConcurrentOperation: 5)
    let errorStream: PassthroughSubject<Error, Never> = PassthroughSubject()
    private var cancellables = Set<AnyCancellable>()

    init(
        fileUploadFactory: FileUploadOperationsProvider,
        storage: StorageManager,
        sessionVault: SessionVault
    ) {
        self.fileUploadFactory = fileUploadFactory
        self.moc = storage.backgroundContext
        self.storage = storage

        sessionVault
            .objectWillChange
            .compactMap(sessionVault.getUserInfo)
            .map(\.availableStorage)
            .receive(on: DispatchQueue.main)
            .sink { [unowned self] in
                restartWaitingOperations(availableStorage: $0)
            }
            .store(in: &cancellables)
    }

    public func restartOperations() throws {
        let uploading = storage.fetchFilesUploading(moc: storage.mainContext)
        restartFilesUpload(files: uploading)
        if queue.operationCount == 0 {
            throw FileUploaderError.missingOperations
        }
    }
    
    public func restartInterruptedUploads() {
        let interrupted = storage.fetchFilesInterrupted(moc: storage.mainContext)
        restartFilesUpload(files: interrupted)
    }
    
    private func restartFilesUpload(files: [File]) {
        for file in files {
            file.managedObjectContext?.performAndWait {
                let uploadID = file.uploadID
                self.upload(file) { [weak self] result in
                    switch result {
                    case .success:
                        break
                    case .failure:
                        self?.cancel(uploadID: uploadID)
                    }
                }
            }
        }
    }

    public func pause(file: File) {
        if let uploadID = file.uploadID {
            queue.operations
                .compactMap { $0 as? MainFileUploaderOperation }
                .filter { $0.uploadID == uploadID }
                .forEach { $0.pause() }
        }
    }

    public func cancel(uploadID: UUID?) {
        guard let uploadID = uploadID else { return }
        queue.operations
            .first(where: { ($0 as? MainFileUploaderOperation)?.uploadID == uploadID })?
            .cancel()
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
        queue.cancelAllOperations()
    }

    public func pauseAllUploads() {
        NotificationCenter.default.post(name: .didInterruptOnFileUpload, object: nil)
        queue.operations
            .compactMap { $0 as? MainFileUploaderOperation }
            .forEach { $0.interrupt() }
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
        let runningOperationsIDs = Set(queue.operations.compactMap { ($0 as? UploadOperation)?.uploadID })
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
    public func upload(_ file: File, completion: @escaping OnUploadCompletion) -> UploadOperation {
        let draft = FileDraft.extract(from: file, moc: storage.backgroundContext)
        let uploadID = draft.uploadID

        // Do not schedule previously scheduled operations
        cancel(uploadID: uploadID)

        let operations = fileUploadFactory.getOperations(for: draft) { [weak self] result in
            switch result {
            case .success(let file):
                completion(.success(file))
            case .failure(let error):
                NotificationCenter.default.post(name: .didFindIssueOnFileUpload, object: nil)
                ConsoleLogger.shared?.log(DriveError(error, "FileUploader"))

                self?.cancel(uploadID: uploadID)
                self?.errorStream.send(error)
                completion(.failure(error))
            }
        }

        draft.file.changeState(to: .uploading)
        queue.addOperations(operations, waitUntilFinished: false)
        return operations.last as! UploadOperation
    }

}
