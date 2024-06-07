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

final class ThumbnailUploaderOperation: AsynchronousOperation {

    private let id: UUID
    private let index: Int
    private let token: String
    private let progress: Progress
    private let contentUploader: ContentUploader
    private let onError: OnUploadError

    init(
        id: UUID,
        index: Int,
        token: String,
        progress: Progress,
        contentUploader: ContentUploader,
        onError: @escaping OnUploadError
    ) {
        self.id = id
        self.index = index
        self.token = token
        self.progress = progress
        self.contentUploader = contentUploader
        self.onError = onError
        super.init()
    }

    override func main() {
        guard !isCancelled else { return }

        Log.info("STAGE: 3.1 Thumbnail \(index) upload 🏞☁️ started. UUID: \(id.uuidString) Token: \(token)", domain: .uploader)

        contentUploader.upload { [weak self] result in
            guard let self = self, !self.isCancelled else { return }

            switch result {
            case .success:
                Log.info("STAGE: 3.1 Thumbnail \(self.index) upload 🏞☁️ finished ✅. UUID: \(self.id.uuidString) Token: \(self.token)", domain: .uploader)
                self.progress.complete()
                self.state = .finished

            case .failure(let error as ResponseError) where error.isRetryable:
                Log.info("STAGE: 3.1 Thumbnail \(self.index) upload 🏞☁️ not finished ⚠️. UUID: \(self.id.uuidString) Token: \(self.token)", domain: .uploader)
                Log.error("UUID: \(self.id.uuidString) ERROR: \(error)", domain: .uploader)
                self.state = .finished

            case .failure(let error):
                Log.info("STAGE: 3.1 Thumbnail \(self.index) upload 🏞☁️ finished ❌. UUID: \(self.id.uuidString) Token: \(self.token)", domain: .uploader)
                Log.error("UUID: \(self.id.uuidString) ERROR: \(error)", domain: .uploader)
                self.onError(error)
            }
        }
    }

    override func cancel() {
        contentUploader.cancel()
        super.cancel()
    }

}
