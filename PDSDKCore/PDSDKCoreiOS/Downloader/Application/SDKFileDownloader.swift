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

import Combine
import PDCore
import Foundation
import ProtonDriveSDK

@MainActor class SDKFileDownloader: SDKFileDownloaderProtocol {
    enum Domain: String {
        case file
        case photo
    }
    
    private let interactor: FileDownloadInteractorProtocol
    private let tokenStore: CancellationTokenStore
    private let progressesSubject = CurrentValueSubject<[AnyVolumeIdentifier: Progress], Never>([:])
    private let failuresSubject = PassthroughSubject<(AnyVolumeIdentifier, Error), Never>()
    private let domain: Domain

    let bytesCounterResource: BytesCounterResource

    var progresses: AnyPublisher<[AnyVolumeIdentifier: Progress], Never> {
        progressesSubject
            // Throttle to avoid too many updates on UI (main thread)
            .throttle(for: .milliseconds(200), scheduler: DispatchQueue.main, latest: true)
            .eraseToAnyPublisher()
    }

    var failures: AnyPublisher<(AnyVolumeIdentifier, Error), Never> {
        failuresSubject
            .eraseToAnyPublisher()
    }

    var isActivePublisher: AnyPublisher<Bool, Never> {
        progresses
            .map { !$0.isEmpty }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    init(
        interactor: FileDownloadInteractorProtocol,
        bytesCounterResource: BytesCounterResource,
        tokenStore: CancellationTokenStore,
        domain: Domain
    ) {
        self.interactor = interactor
        self.bytesCounterResource = bytesCounterResource
        self.tokenStore = tokenStore
        self.domain = domain
    }

    nonisolated func download(file identifier: AnyVolumeIdentifier) async throws {
        try await download(file: identifier, options: [])
    }

    nonisolated func download(file identifier: AnyVolumeIdentifier, options: SDKFileDownloadOptions) async throws {
        guard await tokenStore.token(for: identifier) == nil else {
            Log.debug("Ignore request to download \(identifier) because it's downloading", domain: .sdk)
            return
        }

        let cancellationToken = UUID()
        await tokenStore.setToken(cancellationToken, for: identifier)
        do {
            try await interactor.download(
                file: identifier,
                cancellationToken: cancellationToken,
                options: options,
                progress: { [weak self] fileProgress in
                    Task {
                        Log.debug("Updated download progress: \(fileProgress.fractionCompleted)", domain: .sdk)
                        await self?.updateProgress(
                            identifier: identifier,
                            total: fileProgress.bytesTotal,
                            completed: fileProgress.bytesCompleted
                        )
                    }
                },
                checkCancellation: { [weak self] in
                    if await self?.tokenStore.token(for: identifier) == nil {
                        Log.info("Download was cancelled before SDK was invoked. Throwing cancel", domain: .sdk)
                        throw CancellationError()
                    }
                }
            )
            await updateProgressToCompleted(for: identifier)
            await removeProgress(for: identifier)
        } catch {
            await removeProgress(for: identifier)
            if let sdkError = error as? ProtonDriveSDKError, sdkError.isCancellationError {
                throw SDKDownloadErrors.cancelled
            } else if error is CancellationError {
                throw SDKDownloadErrors.cancelled
            }
            failuresSubject.send((identifier, error))
            Log.error("Failed to download (\(domain)). \(error.localizedDescription)", error: error, domain: .sdk)
            throw error
        }
    }

    private func removeProgress(for identifier: AnyVolumeIdentifier) async {
        await tokenStore.remove(for: identifier)
        var progresses = progressesSubject.value
        progresses[identifier] = nil
        progressesSubject.send(progresses)
    }

    private func updateProgress(identifier: AnyVolumeIdentifier, total: Int64? = nil, completed: Int64? = nil) {
        var progresses = progressesSubject.value
        let isCreatingNewProgress = progresses[identifier] == nil
        let progress = progresses[identifier] ?? Progress()
        if let total {
            progress.totalUnitCount = total
            if let completed {
                let completed = min(total, completed)
                let previouslyCompleted = progress.completedUnitCount
                bytesCounterResource.add(bytes: Int(completed - previouslyCompleted))
                progress.completedUnitCount = completed
            }
        }
        if isCreatingNewProgress {
            progresses[identifier] = progress
            progressesSubject.send(progresses) // Only send update when there's a new progress. Otherwise the UI is glitchy
        }
    }

    /// Notifies 100% finished upon completion
    private func updateProgressToCompleted(for identifier: AnyVolumeIdentifier) {
        guard let progress = progressesSubject.value[identifier] else {
            return
        }
        guard progress.completedUnitCount < progress.totalUnitCount else {
            return
        }
        progress.completedUnitCount = progress.totalUnitCount
    }
}

// MARK: - DownloaderProtocol
extension SDKFileDownloader: DownloaderProtocol {
    nonisolated func cancel(operationsOf identifiers: [any VolumeIdentifiable]) {
        guard !identifiers.isEmpty else {
            return
        }
        Log.info("Cancel download \(identifiers)", domain: .sdk)
        Task {
            let tokens = await identifiers.asyncCompactMap { identifier in
                await tokenStore.remove(for: identifier.any())
            }
            await self.interactor.cancel(with: tokens)
        }
    }

    nonisolated func cancelAll() {
        Log.info("Cancel all of download tasks", domain: .sdk)
        Task {
            let tokens = await tokenStore.removeAll().values
            await self.interactor.cancel(with: Array(tokens))
        }
    }
}
