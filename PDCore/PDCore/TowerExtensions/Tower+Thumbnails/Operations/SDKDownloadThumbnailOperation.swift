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

import Foundation
import PDClient

final class SDKDownloadThumbnailOperation: ThumbnailIdentifiableOperation, @unchecked Sendable {
    private let type: ThumbnailType
    private let downloader: SDKThumbnailsDownloaderProtocol

    init(identifier: any VolumeIdentifiable, type: ThumbnailType, downloader: SDKThumbnailsDownloaderProtocol) {
        self.type = type
        self.downloader = downloader
        super.init(identifier: NodeIdentifier(identifier.id, "", identifier.volumeID)) // share id is not used
    }

    override func main() {
        guard !self.isCancelled else { return }

        Task {
            await execute()
        }
    }

    private func execute() async {
        guard !isCancelled else { return }

        do {
            let result = try await downloader.downloadThumbnail(for: identifier.any(), type: type)
            if result == nil {
                finishOperationWithEmpty()
            } else {
                finishOperationWithSuccess()
            }
        } catch {
            finishOperationWithFailure(error)
        }
    }

    override func cancel() {
        super.cancel()
        downloader.cancel([identifier.any()], type: type)
    }
}
