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

import Foundation
import CoreData

public class MyFilesFileUploader: FileUploader {
    public func upload(files: [File]) {
        files.forEach { file in
            self.upload(file, completion: { _ in })
        }
    }

    override public func upload(_ file: File, completion: @escaping OnUploadCompletion = { _ in }) {
        guard !didSignOut else { return }

        return moc.perform { [weak self] in
            guard let self, !self.didSignOut else { return }

            let file = file.in(moc: self.moc)
            Log.info("0️⃣ file pload will start. File: \(file.id), UUID: \(String(describing: file.uploadID))", domain: .uploader)

            do {
                try self.canUploadWithError(file)
                file.isUploading = true
                self.upload(file, retryCount: 0, completion: completion)
            } catch CanUploadError.isUploading {
                Log.info("0️⃣⚠️ file upload could not start \(CanUploadError.isUploading), File: \(file.id), UUID: \(String(describing: file.uploadID))", domain: .uploader)
            } catch CanUploadError.processingOperationAlreadyExists {
                Log.info("0️⃣⚠️ file upload could not start \(CanUploadError.processingOperationAlreadyExists), File: \(file.id), UUID: \(String(describing: file.uploadID))", domain: .uploader)
            } catch {
                Log.info("0️⃣❌ file upload could not start \(error), File: \(file.id), UUID: \(String(describing: file.uploadID))", domain: .uploader)
            }
        }
    }

    private func upload(_ file: File, retryCount: Int, completion: @escaping OnUploadCompletion) {
        guard !didSignOut else { return }

        do {
            let draft = try FileDraft.extract(from: file)
            let uploadID = draft.uploadID
            Log.info("1️⃣ file upload will start, retry: \(retryCount), UUID: \(uploadID), FileID \(file.id)", domain: .uploader)
            initializeMeasurement(of: draft.uri)

            let operation = fileUploadFactory.getOperations(for: draft) { [weak self] result in
                guard let self = self, !self.didSignOut else { return }

                switch result {
                case .success(let file):
                    Log.info("2️⃣ file upload success, retry: \(retryCount), UUID: \(uploadID)", domain: .uploader)
                    self.handleGlobalSuccess(fileDraft: draft, completion: completion)

                case .failure(let error):
                    Log.error("2️⃣❌ file upload failure. Error: \(error.localizedDescription), retry: \(retryCount), UUID: \(uploadID)", domain: .uploader)
                    self.handleGlobalError(error, fileDraft: draft, retryCount: retryCount, completion: completion)
                }
            }
            draft.file.isUploading = true
            draft.file.changeUploadingState(to: .uploading)
            Log.info("Queue status - operationCount: \(queue.operationCount) - isSuspended: \(queue.isSuspended)", domain: .updater)
            addOperation(operation)
        } catch is AlreadyCommittedFileError {
            Log.info("🫨❌ file was already commited, UUID: \(String(describing: file.uploadID)), id: \(file.id)", domain: .uploader)
            file.isUploading = false
        } catch let error as ContentCleanedError {
            Log.info("1️⃣❌🧹 file upload failure, UUID: \(String(describing: file.uploadID))", domain: .uploader)
            deleteUploadingFile(file)
            handleDefaultError(error, completion: completion)
        } catch {
            Log.info("1️⃣❌ file upload failure, UUID: \(String(describing: file.uploadID))", domain: .uploader)
            handleDefaultError(error, completion: completion)
            file.isUploading = false
        }
    }
    
    func handleGlobalSuccess(fileDraft: FileDraft, completion: @escaping OnUploadCompletion) {
        guard !didSignOut else { return }
        completion(.success(fileDraft.file))
    }

    func handleGlobalError(_ error: Error, fileDraft: FileDraft, retryCount: Int, completion: @escaping OnUploadCompletion) {
        guard !didSignOut else { return }

        guard !(error is NSManagedObject.NoMOCError) else {
            return
        }

        let uploadID = fileDraft.uploadID
        let file = fileDraft.file

        if let responseError = error as? ResponseError {

            if responseError.isExpiredResource {
                file.handleExpiredRemoteRevisionDraftReference()
            }

            if responseError.isRetryable {
                handleRetryOnError(responseError, file: file, retryCount: retryCount, uploadID: uploadID, completion: completion)
            } else {
                cancelOperation(id: uploadID)
                file.makeUploadableAgain()
                handleDefaultError(error, completion: completion)
            }

        } else if error is NSManagedObject.InvalidState {
            cancelOperation(id: uploadID)
            deleteUploadingFile(file)
            handleDefaultError(error, completion: completion)
        } else if error is AlreadyCommittedFileError {
            cancelOperation(id: uploadID)
        } else {
            cancelOperation(id: uploadID)
            file.makeUploadableAgain()
            handleDefaultError(error, completion: completion)
        }
    }

    func handleRetryOnError(_ error: Error, file: File, retryCount: Int, uploadID: UUID, completion: @escaping OnUploadCompletion) {
        guard !didSignOut else { return }

        if retryCount < maximumRetries {
            let delay = ExponentialBackoffWithJitter.getDelay(attempt: retryCount)
            Log.info("3️⃣♻️ file upload failure ☠️, retry: \(retryCount), UUID: \(uploadID), nextDelay: \(delay)", domain: .uploader)
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.isEnabled, !self.didSignOut else { return }
                self.cancelForRetry(id: uploadID)
                self.moc.perform {
                    Log.info("4️⃣♻️ BEFORE ops: \(self.processingQueue.operations.compactMap({ $0 as? FileUploaderOperation }).map(\.id))", domain: .uploader)
                    self.upload(file, retryCount: retryCount + 1, completion: completion)
                    Log.info("4️⃣♻️ AFTER ops: \(self.processingQueue.operations.compactMap({ $0 as? FileUploaderOperation }).map(\.id))", domain: .uploader)
                }
            }
        } else {
            Log.info("3️⃣♻️❌ file upload failure, retry: \(retryCount), UUID: \(uploadID)", domain: .uploader)
            cancelOperation(id: uploadID)
            file.makeUploadableAgain()
            handleDefaultError(error, completion: completion)
        }
    }

    var maximumRetries: Int {
        10
    }

    public final func cancelForRetry(id: UUID) {
        getProcessingOperation(with: id)?.cancelForRetry()
    }

    // MARK: Telemetry
    
    func initializeMeasurement(of item: String) {
        // Used by descendants
    }
}
