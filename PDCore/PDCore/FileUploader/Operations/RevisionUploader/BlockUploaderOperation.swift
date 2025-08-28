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

final class BlockUploaderOperation: AsynchronousOperation, OperationWithProgress {

    let progress: Progress

    private let id: UUID
    private let token: String
    private let index: Int
    private let contentUploader: ContentUploader
    private let onError: OnUploadError
    private let measurementRepository: FileUploadBlocksMeasurementRepositoryProtocol?

    init(
        id: UUID,
        index: Int,
        token: String,
        progressTracker: Progress,
        contentUploader: ContentUploader,
        measurementRepository: FileUploadBlocksMeasurementRepositoryProtocol?,
        onError: @escaping OnUploadError
    ) {
        self.id = id
        self.token = token
        self.progress = progressTracker
        self.index = index
        self.contentUploader = contentUploader
        self.measurementRepository = measurementRepository
        self.onError = onError
        super.init()
    }

    override func main() {
        guard !isCancelled else { return }
        Log.info("STAGE: 3.2 Block \(index) upload 📦☁️ started. UUID: \(id.uuidString) Token: \(token)", domain: .uploader)

        contentUploader.upload { [weak self] result in
            guard let self = self, !self.isCancelled else { return }

            switch result {
            case .success:
                Log.info("STAGE: 3.2 Block \(self.index) upload 📦☁️ finished ✅. UUID: \(self.id.uuidString) Token: \(self.token)", domain: .uploader)
                #if os(iOS)
                self.progress.complete()
                #endif
                self.measurementRepository?.trackBlockUploadSuccess()
                self.state = .finished

            case .failure(let error as ResponseError) where error.isRetryable:
                Log.info("STAGE: 3.2 Block \(self.index) upload 📦☁️ not finished ⚠️. UUID: \(self.id.uuidString) Token: \(self.token)", domain: .uploader)
                Log
                    .error(
                        "BlockUploader upload failed (retryable)",
                        error: error,
                        domain: .uploader,
                        context: LogContext("UUID: \(self.id.uuidString)")
                    )
                self.state = .finished

            case .failure(let error):
                Log.info("STAGE: 3.2 Block \(self.index) upload 📦☁️ finished ❌. UUID: \(self.id.uuidString) Token: \(self.token)", domain: .uploader)
                Log
                    .error(
                        "BlockUploader upload failed",
                        error: error,
                        domain: .uploader,
                        context: LogContext("UUID: \(self.id.uuidString)")
                    )
                self.onError(error)
            }
        }
    }

    override func cancel() {
        contentUploader.cancel()
        super.cancel()
    }
}
