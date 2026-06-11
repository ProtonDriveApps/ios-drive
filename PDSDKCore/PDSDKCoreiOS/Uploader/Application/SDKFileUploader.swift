// Copyright (c) 2025 Proton AG
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

@preconcurrency import PDCore
import Combine
import CoreData
import PDSDKCore
import ProtonDriveSDK

@MainActor class SDKFileUploader: SDKFileUploaderProtocol {
    typealias UploadID = UUID
    private let cacheResource: FileUploaderCacheProtocol
    private let interactor: FileUploadInteractorProtocol
    private let notificationCenter: NotificationCenter
    private let protectionResource: ProtectionResource
    private let tokenStore: CancellationTokenStore
    private var pausedUploadIDs = CurrentValueSubject<Set<UploadID>, Never>([])
    private let localNotificationResource: FileUploadNotificationResourceProtocol?
    private let failuresSubject = PassthroughSubject<(AnyVolumeIdentifier, Error), Never>()
    private let progressesSubject = CurrentValueSubject<[UploadID: Progress], Never>([:])
    private let duplicatedSubject = PassthroughSubject<(AnyVolumeIdentifier, String), Never>()
    let bytesCounterResource: BytesCounterResource
    /// Render error toast
    var failures: AnyPublisher<(AnyVolumeIdentifier, Error), Never> {
        failuresSubject.eraseToAnyPublisher()
    }
    var progresses: AnyPublisher<[UploadID: Progress], Never> {
        progressesSubject.eraseToAnyPublisher()
    }
    var duplicated: AnyPublisher<(AnyVolumeIdentifier, String), Never> {
        duplicatedSubject.eraseToAnyPublisher()
    }
    /// Conformance to speed measurements. Is interested in "running" operations, so we need to filter out paused ones (paused ones are kept in `progresses`)
    var hasOperations: AnyPublisher<Bool, Never> {
        progresses.combineLatest(pausedUploadIDs)
            .map { progresses, pausedUploadIDs -> Bool in
                guard !progresses.isEmpty else {
                    return false
                }
                guard !pausedUploadIDs.isEmpty else {
                    return true
                }
                let progressesKeys = Set(progresses.keys)
                let nonPausedProgressesCount = progressesKeys.subtracting(pausedUploadIDs).count
                return nonPausedProgressesCount > 0
            }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    init(
        bytesCounterResource: BytesCounterResource,
        cacheResource: FileUploaderCacheProtocol,
        interactor: FileUploadInteractorProtocol,
        notificationCenter: NotificationCenter = .default,
        protectionResource: ProtectionResource,
        tokenStore: CancellationTokenStore,
        localNotificationResource: FileUploadNotificationResourceProtocol? = nil
    ) {
        self.bytesCounterResource = bytesCounterResource
        self.cacheResource = cacheResource
        self.interactor = interactor
        self.notificationCenter = notificationCenter
        self.protectionResource = protectionResource
        self.tokenStore = tokenStore
        self.localNotificationResource = localNotificationResource
    }

    /// - Parameter identifier: Temporary file identifier, the id is a temporary UUID
    /// - Returns: Actual identifier returned after the upload succeeds.
    nonisolated func upload(identifier: AnyVolumeIdentifier) async throws -> AnyVolumeIdentifier {
        try await upload(identifier: identifier, duplicateAction: nil)
    }

    /// - Parameter identifier: Temporary file identifier, the id is a temporary UUID
    /// - Returns: Actual identifier returned after the upload succeeds.
    nonisolated func upload(
        identifier: AnyVolumeIdentifier,
        duplicateAction: DuplicateUploadAction?
    ) async throws -> AnyVolumeIdentifier {
        Log.debug("Schedule to upload \(identifier)", domain: .sdk)
        let properties = try await cacheResource.get(properties: [\.uploadID, \.size], from: identifier)
        guard
            properties.count == 2,
            let uploadID = properties.first as? UploadID,
            let fileSize = properties.last as? Int
        else { throw SDKUploadErrors.invalidFileData }

        try await prepareForUpload(identifier: identifier, uploadID: uploadID, fileSize: fileSize)

        do {
            await localNotificationResource?.notify(start: true)
            /// By the end of upload, the temporary `identifier` is replaced by the real BE `uploadIdentifier`
            let resultIdentifier = try await interactor.upload(
                identifier: identifier,
                token: uploadID,
                conflictResolution: duplicateAction?.sdk ?? .undetermined,
            ) { [weak self] uploadProgress in
                Task {
                    Log.debug("Updated upload progress: \(uploadProgress.fractionCompleted)", domain: .sdk)
                    await self?.updateProgress(
                        uploadID: uploadID,
                        total: uploadProgress.bytesTotal,
                        completed: uploadProgress.bytesCompleted
                    )
                }
            }
            await removeProgress(for: uploadID)
            await tokenStore.remove(for: identifier)
            await sendDidUploadNotification()
            let interactorType = await interactor.type
            Log.debug("Upload \(interactorType) success \(resultIdentifier), uploadID: \(uploadID)", domain: .sdk)
            await localNotificationResource?.notify(start: false)
            return resultIdentifier
        } catch let error as FileUploadInteractorError {
            Log.debug("Handle error, uploadID: \(uploadID), error: \(error.localizedDescription))", domain: .sdk)
            await localNotificationResource?.notify(error: error)
            switch error {
            case .cancelled:
                try await handleCancelled(identifier: identifier, uploadID: uploadID)
                throw SDKUploadErrors.cancelled
            case .paused:
                try await handlePaused(identifier: identifier, uploadID: uploadID)
                throw SDKUploadErrors.cancelled
            case let .error(error):
                if let sdkError = error as? ProtonDriveSDKError,
                   sdkError.type == "Proton.Drive.Sdk.NodeWithSameNameExistsException" {
                    try await handleDuplicationError(identifier: identifier, uploadID: uploadID)
                } else {
                    try await handleGenericError(identifier: identifier, error: error, uploadID: uploadID)
                }
                throw error
            }
        } catch is CancellationError {
            Log.debug("Handle cancellation for uploadID: \(uploadID)", domain: .sdk)
            try await handleCancelled(identifier: identifier, uploadID: uploadID)
            throw SDKUploadErrors.cancelled
        } catch {
            assertionFailure("Failed to throw `FileUploadInteractorError`")
            try await handleGenericError(identifier: identifier, error: error, uploadID: uploadID)
            throw error
        }
    }

    private func prepareForUpload(identifier: AnyVolumeIdentifier, uploadID: UUID, fileSize: Int) async throws {
        if !pausedUploadIDs.value.contains(uploadID) {
            guard !progressesSubject.value.keys.contains(uploadID) else {
                throw SDKUploadErrors.isUploading
            }
            // If it's not paused, then we add initial progress with total size
            try setAndSendProgress(for: uploadID, fileSize: Int64(fileSize))
        }
        removePausedUploadID(uploadID)
        await tokenStore.setToken(uploadID, for: identifier)
    }

    private func handlePaused(identifier: AnyVolumeIdentifier, uploadID: UUID) async throws {
        insertPausedUploadID(uploadID)
        try await cacheResource.updateState(for: identifier, to: .interrupted)
    }

    private func handleCancelled(identifier: AnyVolumeIdentifier, uploadID: UUID) async throws {
        removePausedUploadID(uploadID)
        await tokenStore.remove(for: identifier)
        removeProgress(for: uploadID)
        try await handleUploadFailure(identifier: identifier)
    }

    private func handleGenericError(identifier: AnyVolumeIdentifier, error: Error, uploadID: UUID) async throws {
        removePausedUploadID(uploadID)
        await tokenStore.remove(for: identifier)
        removeProgress(for: uploadID)
        try await handleUploadFailure(identifier: identifier)
        failuresSubject.send((identifier, error))
        if protectionResource.isLocked() {
            throw SDKUploadErrors.cancelled
        }
    }
    
    private func removePausedUploadID(_ uploadID: UUID) {
        var pausedUploadIDsValue = pausedUploadIDs.value
        pausedUploadIDsValue.remove(uploadID)
        pausedUploadIDs.send(pausedUploadIDsValue)
    }
    
    private func insertPausedUploadID(_ uploadID: UUID) {
        var pausedUploadIDsValue = pausedUploadIDs.value
        pausedUploadIDsValue.insert(uploadID)
        pausedUploadIDs.send(pausedUploadIDsValue)
    }

    private func handleDuplicationError(identifier: AnyVolumeIdentifier, uploadID: UUID) async throws {
        let properties = try await cacheResource.get(properties: [\.decryptedName], from: identifier)
        guard let name = properties.first as? String else { return }
        try await handleCancelled(identifier: identifier, uploadID: uploadID)
        duplicatedSubject.send((identifier, name))
    }

    func deleteUploadingFile(identifier: AnyVolumeIdentifier) async throws {
        await cancel(identifier: identifier)
        await cacheResource.deleteTemp(identifier: identifier)
    }

    func cancel(identifier: AnyVolumeIdentifier) async {
        guard let token = await tokenStore.token(for: identifier) else {
            Log.warning("No upload token for identifier \(identifier)", domain: .sdk)
            return
        }
        await interactor.cancel(token: token)
        await tokenStore.remove(for: identifier)
    }

    func cancelAll() async {
        let tokens = await tokenStore.removeAll().values
        Log.debug("Cancelling \(tokens.count) uploads", domain: .sdk)
        await tokens.parallelForEach { token in
            await self.interactor.cancel(token: token)
            self.removeProgress(for: token)
        }
        Log.debug("Cancelled all uploads", domain: .sdk)
    }

    func pause(identifier: AnyVolumeIdentifier) async {
        guard let token = await tokenStore.token(for: identifier) else {
            return
        }
        let interactorType = interactor.type
        Log.debug("Pausing \(interactorType) upload with identifier: \(identifier)", domain: .sdk)
        await pause(token: token, identifier: identifier)
    }

    nonisolated private func pause(token: UUID, identifier: AnyVolumeIdentifier) async {
        do {
            try await interactor.pause(token: token)
            try await cacheResource.updateState(for: identifier, to: .paused)
        } catch {
            Log.error("Failed to pause upload. Cancelling instead", error: error, domain: .sdk)
            await cancel(identifier: identifier)
        }
    }

    func pauseAll() async {
        let tokens = await tokenStore.tokens
        guard !tokens.isEmpty else {
            return
        }
        Log.debug("Pausing \(tokens.count) uploads", domain: .sdk)
        await tokens.parallelForEach { item in
            await self.pause(token: item.value, identifier: item.key)
        }
        Log.debug("Paused all uploads", domain: .sdk)
    }

    func resumePausedUploads() async {
        let pausedIdentifiers = await interactor.getPausedIdentifiers()
        guard !pausedIdentifiers.isEmpty else{
            return
        }
        Log.info("Resuming \(pausedIdentifiers.count) upload(s).", domain: .sdk)
        await pausedIdentifiers.parallelForEach { identifier in
            _ = try? await self.upload(identifier: identifier)
        }
    }

    func activeUploadsCount() -> Int {
        progressesSubject.value.count
    }
}

// MARK: - Progress
extension SDKFileUploader {
    private func setAndSendProgress(for uploadID: UploadID, fileSize: Int64) throws {
        let progress = Progress(totalUnitCount: fileSize)
        var progresses = progressesSubject.value
        guard progresses[uploadID] == nil else {
            throw SDKUploadErrors.isUploading
        }
        progresses[uploadID] = progress
        progressesSubject.send(progresses)
        Log.debug("Set and send upload progress for \(uploadID)", domain: .sdk)
    }

    private func updateProgress(uploadID: UploadID, total: Int64? = nil, completed: Int64? = nil) {
        guard let progress = progressesSubject.value[uploadID] else { return }
        if let total {
            progress.totalUnitCount = total
            if let completed {
                let completed = min(total, completed)
                let previouslyCompleted = progress.completedUnitCount
                bytesCounterResource.add(bytes: Int(completed - previouslyCompleted))
                progress.completedUnitCount = completed
            }
        }
    }

    private func removeProgress(for uploadID: UploadID) {
        var progresses = progressesSubject.value
        if progresses[uploadID] == nil { return }
        progresses[uploadID] = nil
        progressesSubject.send(progresses)
        Log.debug("Remove upload progress for \(uploadID)", domain: .sdk)
    }
}

// MARK: - Post process
extension SDKFileUploader {
    private func sendInterruptNotification() {
        if interactor.type == .file {
            notificationCenter.post(name: .didInterruptOnFileUpload, object: nil)
        } else if interactor.type == .photo {
            notificationCenter.post(name: .didInterruptOnPhotoUpload, object: nil)
        } else {
            assertionFailure("Unrecognized interactor")
        }
    }

    private func sendDidUploadNotification() {
        if interactor.type == .file {
            notificationCenter.post(name: .didUploadFile)
        } else if interactor.type == .photo {
            notificationCenter.post(name: .didUploadPhoto)
            notificationCenter.post(name: .uploadPendingPhotos)
        }
    }

    private func handleUploadFailure(identifier: AnyVolumeIdentifier) async throws {
        if interactor.type == .file {
            try await cacheResource.updateState(for: identifier, to: .interrupted)
        } else if interactor.type == .photo {
            await cacheResource.deleteTemp(identifier: identifier)
        }
    }
}
