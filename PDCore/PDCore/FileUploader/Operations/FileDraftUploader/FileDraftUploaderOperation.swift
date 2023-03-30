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

final class FileDraftUploaderOperation: AsynchronousOperation, UploadOperation {
    let progress: Progress
    let uploadID: UUID

    private let unitOfWork: UnitOfWork
    private let draft: FileDraft
    private let fileDraftUploader: FileDraftUploader
    private let onError: OnError

    init(
        unitOfWork: UnitOfWork,
        draft: FileDraft,
        fileDraftUploader: FileDraftUploader,
        onError: @escaping OnError
    ) {
        self.unitOfWork = unitOfWork
        self.progress = Progress(unitsOfWork: unitOfWork)
        self.draft = draft
        self.fileDraftUploader = fileDraftUploader
        self.onError = onError
        self.uploadID = draft.uploadID
        super.init()
    }

    override func main() {
        guard !isCancelled else { return }

        record()

        ConsoleLogger.shared?.log("STAGE: 1 Upload draft ✍️☁️ started", osLogType: FileUploader.self)
        fileDraftUploader.upload(draft: draft.file) { [weak self] result in
            guard let self = self, !self.isCancelled else { return }

            switch result {
            case .success:
                ConsoleLogger.shared?.log("STAGE: 1 Upload draft ✍️☁️ finished ✅", osLogType: FileUploader.self)
                self.progress.unitsOfWorkCompleted = self.unitOfWork
                self.state = .finished

            case .failure(let error):
                ConsoleLogger.shared?.log("STAGE: 1 Upload draft ✍️☁️ finished ❌", osLogType: FileUploader.self)
                self.onError(error)
            }
        }
    }

    override func cancel() {
        ConsoleLogger.shared?.log("🙅‍♂️🙅‍♂️🙅‍♂️🙅‍♂️ CANCEL \(type(of: self))", osLogType: FileUploader.self)
        super.cancel()
        fileDraftUploader.cancel()
    }

    var recordingName: String { "creatingFileDraft" }
}
