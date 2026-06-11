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

actor SDKThumbnailsDownloader: SDKThumbnailsDownloaderProtocol { // Is not needed to be MainActor atm
    private let interactor: ThumbnailsDownloadInteractor

    init(interactor: ThumbnailsDownloadInteractor) {
        self.interactor = interactor
    }

    func downloadThumbnail(
        for file: AnyVolumeIdentifier,
        type: ThumbnailType
    ) async throws -> AnyVolumeIdentifier? {
        do {
            return try await interactor.downloadThumbnail(file: file, type: type)
        } catch {
            if let sdkError = error as? ProtonDriveSDKError, sdkError.isCancellationError {
                throw SDKDownloadErrors.cancelled
            } else if error is CancellationError {
                throw SDKDownloadErrors.cancelled
            }

            Log.error("Failed to download a thumbnail: \(error.localizedDescription)", error: error, domain: .sdk, context: LogContext("fileDescription: \(file.debugDesc)"))
            throw error
        }
    }

    nonisolated func cancel(_ identifiers: [AnyVolumeIdentifier], type: ThumbnailType) {
        Task {
            await withTaskGroup(of: Void.self) { group in
                for id in identifiers {
                    group.addTask {
                        await self.interactor.cancel(file: id.any(), type: type)
                    }
                }
            }
        }
    }
}
