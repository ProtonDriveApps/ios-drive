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

final class PaginatedRevisionUploaderOperation: AsynchronousOperation, UploadOperation {

    let uploadID: UUID
    let progress: Progress

    private let draft: FileDraft
    private let uploader: RevisionUploader
    private let onError: OnError

    init(
        draft: FileDraft,
        parentProgress: Progress,
        uploader: RevisionUploader,
        onError: @escaping OnError
    ) {
        self.draft = draft
        self.progress = parentProgress
        self.uploader = uploader
        self.uploadID = draft.uploadID
        self.onError = onError
        super.init()
    }

    override func main() {
        guard !isCancelled else { return }

        record()

        ConsoleLogger.shared?.log("STAGE: 3 Upload Revision 🏞📦📝☁️ started", osLogType: FileUploader.self)

        // swiftlint:disable:next todo
        // TODO: Improve this in order not to have flow control statements all over the place
        guard !draft.isEmpty else {
            ConsoleLogger.shared?.log("STAGE: 3 Upload Revision 🏞📦📝☁️ finished ✅", osLogType: FileUploader.self)
            progress.complete()
            state = .finished
            return
        }

        uploader.upload(draft) { [weak self] result in
            guard let self = self, !self.isCancelled else { return }

            switch result {
            case .success:
                ConsoleLogger.shared?.log("STAGE: 3 Upload Revision 🏞📦📝☁️ finished ✅", osLogType: FileUploader.self)
                self.progress.complete()
                self.state = .finished

            case .failure(let error):
                ConsoleLogger.shared?.log("STAGE: 3 Upload Revision 🏞📦📝☁️ finished ❌", osLogType: FileUploader.self)
                self.onError(error)
            }
        }
    }

    override func cancel() {
        ConsoleLogger.shared?.log("🙅‍♂️ CANCEL \(type(of: self))", osLogType: FileUploader.self)
        uploader.cancel()
        super.cancel()
    }

    var recordingName: String { "uploadingRevision" }

}
