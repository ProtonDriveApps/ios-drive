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

    private let blockIndex: Int
    private let contentUploader: ContentUploader
    private let onError: OnUploadError

    init(
        progressTracker: Progress,
        blockIndex: Int,
        contentUploader: ContentUploader,
        onError: @escaping OnUploadError
    ) {
        self.progress = progressTracker
        self.blockIndex = blockIndex
        self.contentUploader = contentUploader
        self.onError = onError
        super.init()
    }

    override func main() {
        guard !isCancelled else { return }
        ConsoleLogger.shared?.log("STAGE: 3.2 Block \(blockIndex) upload 📦☁️ started", osLogType: FileUploader.self)

        contentUploader.upload() { [weak self] result in
            guard let self = self, !self.isCancelled else { return }

            switch result {
            case .success:
                ConsoleLogger.shared?.log("STAGE: 3.2 Block \(self.blockIndex) upload 📦☁️ finished ✅", osLogType: FileUploader.self)
                self.progress.complete()
                self.state = .finished

            case .failure(let error) where error is UploadNonCompleted:
                ConsoleLogger.shared?.log("STAGE: 3.2 Block \(self.blockIndex) upload 📦☁️ not finished ⚠️", osLogType: FileUploader.self)
                self.state = .finished

            case .failure(let error):
                ConsoleLogger.shared?.log("STAGE: 3.2 Block \(self.blockIndex) upload 📦☁️ finished ❌", osLogType: FileUploader.self)
                self.onError(error)
            }
        }
    }

    override func cancel() {
        ConsoleLogger.shared?.log("🙅‍♂️🙅‍♂️🙅‍♂️ CANCEL \(type(of: self)), block: \(blockIndex)", osLogType: FileUploader.self)
        contentUploader.cancel()
        super.cancel()
    }
}
