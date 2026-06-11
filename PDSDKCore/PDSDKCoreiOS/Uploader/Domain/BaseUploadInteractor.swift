// Copyright (c) 2026 Proton AG
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
import PDCore
import PDSDKCore
import ProtonDriveSDK

class BaseUploadInteractor {
    let operationCancelPerformer: FileOperationCancelPerformerProtocol
    let operationsStore: UploadOperationsStore

    init(operationCancelPerformer: FileOperationCancelPerformerProtocol, operationsStore: UploadOperationsStore) {
        self.operationCancelPerformer = operationCancelPerformer
        self.operationsStore = operationsStore
    }

    // MARK: - Public functions

    func cancel(token: UUID) async {
        do {
            Log.debug("Cancelling upload: \(token.uuidString)", domain: .sdk)
            try await operationCancelPerformer.cancelUpload(cancellationToken: token)
        } catch {
            Log.error("Cancel upload task failed", error: error, domain: .sdk)
        }
        await operationsStore.remove(id: token)
    }

    func pause(token: UUID) async throws {
        guard let item = await operationsStore.get(for: token) else {
            return
        }
        Log.debug("Pausing upload: \(token.uuidString)", domain: .sdk)
        try await item.uploadOperation.pause()
    }

    func getPausedIdentifiers() async -> Set<AnyVolumeIdentifier> {
        let pausedOperations = await operationsStore.getAll().filter { item in
            return (try? await item.uploadOperation.isPaused()) ?? false
        }
        return Set(pausedOperations.map { $0.identifier })
    }

    // MARK: - Common error handling

    func handleAndMap(error: Error, token: UUID) async -> FileUploadInteractorError {
        guard isCancelled(error: error) else {
            await operationsStore.remove(id: token)
            return .error(error)
        }

        if await isPaused(token: token) {
            return .paused
        } else {
            await operationsStore.remove(id: token)
            return .cancelled
        }
    }

    private func isPaused(token: UUID) async -> Bool {
        guard let item = await operationsStore.get(for: token) else {
            return false
        }
        return (try? await item.uploadOperation.isPaused()) ?? false
    }

    private func isCancelled(error: Error) -> Bool {
        guard let sdkError = error as? ProtonDriveSDKError else {
            return false
        }
        return sdkError.isCancellationError
    }
}
