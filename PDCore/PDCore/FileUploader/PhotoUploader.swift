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
import Combine
import CoreData
import ProtonCoreKeymaker
import ProtonCoreObservability

public final class PhotoUploader: MyFilesFileUploader {
    public typealias PhotoID = String

    private let featureFlags: FeatureFlagsRepository
    private let deletedPhotosIdentifierStore: DeletedPhotosIdentifierStoreResource
    private let skippableCache: PhotosSkippableCache
    private let childQueues: [OperationQueue]
    private let durationMeasurementRepository: DurationMeasurementRepository
    private let filesMeasurementRepository: FileUploadFilesMeasurementRepositoryProtocol
    private let measurementRepositoryFactory: PhotoUploadMeasurementRepositoryFactory
    private let protectionResource: ProtectionResource
    private let measurementsQueue = DispatchQueue(label: "PhotoUploader.measurementsQueue")
    private var measurementRepositories = [String: PhotoUploadMeasurementRepository]()
    public let photoUploadedNotifier: PhotoUploadedNotifier
    private var cancellables = Set<AnyCancellable>()

    public init(
        concurrentOperations: Int,
        fileUploadFactory: FileUploadOperationsProvider,
        featureFlags: FeatureFlagsRepository,
        deletedPhotosIdentifierStore: DeletedPhotosIdentifierStoreResource,
        filecleaner: CloudFileCleaner,
        moc: NSManagedObjectContext,
        skippableCache: PhotosSkippableCache,
        dispatchQueue: DispatchQueue,
        childQueues: [OperationQueue],
        durationMeasurementRepository: DurationMeasurementRepository,
        filesMeasurementRepository: FileUploadFilesMeasurementRepositoryProtocol,
        measurementRepositoryFactory: PhotoUploadMeasurementRepositoryFactory,
        protectionResource: ProtectionResource,
        photoUploadedNotifier: PhotoUploadedNotifier
    ) {
        self.deletedPhotosIdentifierStore = deletedPhotosIdentifierStore
        self.childQueues = childQueues
        self.featureFlags = featureFlags
        self.skippableCache = skippableCache
        self.durationMeasurementRepository = durationMeasurementRepository
        self.filesMeasurementRepository = filesMeasurementRepository
        self.measurementRepositoryFactory = measurementRepositoryFactory
        self.protectionResource = protectionResource
        self.photoUploadedNotifier = photoUploadedNotifier
        super.init(concurrentOperations: concurrentOperations, fileUploadFactory: fileUploadFactory, filecleaner: filecleaner, moc: moc, dispatchQueue: dispatchQueue)
        setUpMeasurements()
    }

    public func onUploadsDisabled() {
        Log.info("\(type(of: self)) onUploadsDisabled", domain: .uploader)
        guard !didSignOut else { return }
        cancelAllOperations()
    }

    override public func cancelAllOperations() {
        super.cancelAllOperations()
        childQueues.forEach { $0.cancelAllOperations() }
    }

    override func canUpload(_ file: File) -> Bool {
        guard let photo = file as? Photo else { return false }
        if super.canUpload(photo) {
            return true
        }
        return photo.children.contains { super.canUpload($0) }
    }

    override func canUploadWithError(_ file: File) throws {
        guard let photo = file as? Photo else {
            throw file.invalidState("The File should be a Photo but it's not")
        }
        if let parent = photo.parent, parent.state != .active {
            throw CanUploadPhotoError.photoParenIsNotUploaded
        }
        try super.canUploadWithError(photo)
        Log.info("Will upload photo ⬆️☁️: \(photo.uploadID!) children: \(photo.children.compactMap(\.uploadID))", domain: .uploader)
    }

    enum CanUploadPhotoError: Error, LocalizedError {
        case photoParenIsNotUploaded
    }

    override func handleGlobalSuccess(
        fileDraft: FileDraft,
        retryCount: Int,
        completion: @escaping OnUploadCompletion
    ) {
        photoUploadedNotifier.uploadCompleted(fileDraft: fileDraft)
        markUploadingFileAsSkippable(fileDraft.file)
        measureSuccess(of: fileDraft)
        super.handleGlobalSuccess(fileDraft: fileDraft, retryCount: retryCount, completion: completion)
    }

    override func handleGlobalError(
        _ error: Error,
        fileDraft: FileDraft,
        retryCount: Int,
        completion: @escaping OnUploadCompletion
    ) {
        guard !(error is NSManagedObject.NoMOCError) else {
            return
        }

        guard !protectionResource.isLocked() else {
            // Suspension doesn't kill operations that are already being executed, so they can end up with main key read error after it's wiped.
            // Don't do anything, the device is locked, PhotoUploader will be suspended anyway.
            // Once the device is unlocked, this failed file will be picked up and added to the queue again.
            return
        }
        
        let uploadID = fileDraft.uploadID
        let file = fileDraft.file

        if let responseError = error as? ResponseError {
            if responseError.isExpiredResource {
                file.handleExpiredRemoteRevisionDraftReference()
            }
            
            if responseError.isRetryableIncludingInternetIssues {
                handleRetryOnError(responseError, file: file, retryCount: retryCount, uploadID: uploadID, completion: completion)
            } else {
                cancelOperation(id: uploadID)
                deleteUploadingFile(file, error: PhotosFailureUserError.connectionError)
                handleDefaultError(error, completion: completion)
                measureFailure(of: fileDraft)
            }

        } else if error is NSManagedObject.InvalidState {
            cancelOperation(id: uploadID)
            deleteUploadingFile(file, error: nil)
            handleDefaultError(error, completion: completion)
            measureFailure(of: fileDraft)
        } else if error is AlreadyCommittedFileError {
            cancelOperation(id: uploadID)
        } else {
            let overestimatedRetryCount = retryCount + 3
            if checkNonServerErrorIsRetriable(error), overestimatedRetryCount < maximumRetries {
                handleRetryOnError(error, file: file, retryCount: overestimatedRetryCount, uploadID: uploadID, completion: completion)
            } else {
                cancelOperation(id: uploadID)
                let userError = mapToUserError(error: error)
                deleteUploadingFile(file, error: userError)
                handleDefaultError(error, completion: completion)
                measureFailure(of: fileDraft)
            }
        }
        
        // This function does not call the super, thus it needs to report the error here, unlike the
        // success case which is reported in the base class.
        ObservabilityEnv.report(
            .uploadSuccessRateEvent(
                status: .failure,
                retryCount: retryCount,
                fileDraft: fileDraft)
        )

    }
    
    private func mapToUserError(error: Error) -> PhotosFailureUserError? {
        if let uploadError = error as? FileUploaderError,
           case .insuficientSpace = uploadError {
            return .driveStorageFull
        }
        return error as? PhotosFailureUserError
    }

    override public func pauseAllUploads() {
        NotificationCenter.default.post(name: .didInterruptOnPhotoUpload, object: nil)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.getAllScheduledOperations().forEach { $0.interrupt() }
        }
    }

    func checkNonServerErrorIsRetriable(_ error: Error) -> Bool {
        if let uploaderError = error as? FileUploaderError, case .noCredentialFound = uploaderError {
            return true
        }

        if let sessionVaultError = error as? SessionVault.Errors, case .addressNotFound = sessionVaultError {
            return true
        }

        if let sessionVaultError = error as? SessionVault.Errors, case .noRequiredAddressKey = sessionVaultError {
            return true
        }

        return false
    }

    override public func deleteUploadingFile(_ file: File, error: PhotosFailureUserError? = nil) {
        guard let photo = file as? Photo else {
            Log.error(file.invalidState("The File should be a Photo."), domain: .uploader)
            assert(false, "The File should be a Photo.")
            return
        }
        let cloudIdentifier = photo.iCloudID()
        defer { deletedPhotosIdentifierStore.increment(cloudIdentifier: cloudIdentifier, error: error) }
        super.deleteUploadingFile(file, error: error)
    }
    
    public func markUploadingFileAsSkippable(_ file: File) {
        guard let photo = file as? Photo else {
            Log.error(file.invalidState("The File should be a Photo."), domain: .uploader)
            assert(false, "The File should be a Photo.")
            return
        }
        
        guard let identifier = photo.iOSPhotos() else { return }
        skippableCache.markAsSkippable(identifier, skippableFiles: 1)
    }

    // MARK: Measurements

    private func setUpMeasurements() {
        makeOperatingPublisher()
            .receive(on: measurementsQueue)
            .sink { [weak self] isOperating in
                self?.handleQueueState(isOperating: isOperating)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default
            .getPublisher(for: .operationStart, publishing: String.self)
            .sink { [weak self] draftUri in
                self?.measureStart(of: draftUri)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default
            .getPublisher(for: .operationEnd, publishing: String.self)
            .sink { [weak self] draftUri in
                self?.measurePause(of: draftUri)
            }
            .store(in: &cancellables)
    }

    private func handleQueueState(isOperating: Bool) {
        if isOperating {
            Log.debug("PhotoUploader start upload measuring", domain: .telemetry)
            durationMeasurementRepository.start()
            measurementRepositories.values.forEach { repository in
                repository.resume()
            }
        } else {
            Log.debug("PhotoUploader pause upload measuring", domain: .telemetry)
            durationMeasurementRepository.stop()
            measurementRepositories.values.forEach { repository in
                repository.pause()
            }
        }
    }

    private func makeOperatingPublisher() -> AnyPublisher<Bool, Never> {
        let isQueueResumedPublisher = queue
            .publisher(for: \.isSuspended)
            .map { !$0 }
        return isWorkingPublisher.combineLatest(isQueueResumedPublisher)
            .map { hasOperations, isResumed in
                return hasOperations && isResumed
            }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    func measureStart(of item: String) {
        measurementsQueue.async { [weak self] in
            guard let self else { return }
            Log.debug("Measure photo start, \(item)", domain: .telemetry)
            let repository = measurementRepositories[item] ?? measurementRepositoryFactory.makeMeasurementRepository(for: item)
            measurementRepositories[item] = repository
            repository.resume()
            filesMeasurementRepository.trackFileUploadStart(id: item)
        }
    }

    func measurePause(of item: String) {
        measurementsQueue.async { [weak self] in
            guard let self else { return }
            Log.debug("Measure photo pause, \(item)", domain: .telemetry)
            measurementRepositories[item]?.pause()
        }
    }

    func measureSuccess(of fileDraft: FileDraft) {
        measurementsQueue.async { [weak self] in
            guard let self else { return }
            let item = fileDraft.uri
            Log.debug("Measure photo success, \(item)", domain: .telemetry)
            let repository = measurementRepositories[item]
            repository?.set(kilobytes: fileDraft.roundedKilobytes, mimeType: fileDraft.mimeType)
            repository?.succeed()
            measurementRepositories[item] = nil
            filesMeasurementRepository.trackFileSuccess()
        }
    }

    func measureFailure(of fileDraft: FileDraft) {
        measurementsQueue.async { [weak self] in
            guard let self else { return }
            let item = fileDraft.uri
            Log.debug("Measure photo failure, \(item)", domain: .telemetry)
            let repository = measurementRepositories[item]
            repository?.set(kilobytes: fileDraft.roundedKilobytes, mimeType: fileDraft.mimeType)
            repository?.fail()
            measurementRepositories[item] = nil
            filesMeasurementRepository.trackFileFailure()
        }
    }
}
