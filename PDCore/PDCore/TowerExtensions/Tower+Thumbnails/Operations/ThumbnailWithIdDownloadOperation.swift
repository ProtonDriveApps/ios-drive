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
import PDClient

enum ThumbnailIdentifierDownloadOperationError: Error {
    case invalidResponse
}

final class ThumbnailIdentifierDownloadOperation: DownloadThumbnailOperation {
    private let thumbnailWithId: ThumbnailIdentifier

    init(thumbnailWithId: ThumbnailIdentifier, downloader: ThumbnailDownloader, decryptor: ThumbnailDecryptor, urlFetchInteractor: ThumbnailURLFetchInteractor) {
        self.thumbnailWithId = thumbnailWithId
        super.init(url: nil, thumbnailIdentifier: thumbnailWithId, downloader: downloader, decryptor: decryptor, identifier: thumbnailWithId.nodeIdentifier, urlFetchInteractor: urlFetchInteractor)
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
            let url = try await urlFetchInteractor.execute(thumbnailId: thumbnailWithId.thumbnailId, volumeId: thumbnailWithId.volumeId)
            guard !isCancelled else { return }
            download(url)
        } catch {
            finishOperationWithFailure(error)
        }
    }
}
