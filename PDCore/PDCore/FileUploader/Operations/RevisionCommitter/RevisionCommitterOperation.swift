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

final class RevisionCommitterOperation: AsynchronousOperation, UploadOperation {

    let id: UUID
    let progress = Progress(unitsOfWork: 1)

    private let draft: FileDraft
    private let commiter: RevisionCommitter
    private let onError: OnUploadError

    init(
        draft: FileDraft,
        commiter: RevisionCommitter,
        onError: @escaping OnUploadError
    ) {
        self.draft = draft
        self.commiter = commiter
        self.id = draft.uploadID
        self.onError = onError
        super.init()
    }

    override func main() {
        guard !isCancelled else { return }

        record()

        ConsoleLogger.shared?.log("STAGE: 4. Revision committer 📑🔐 started", osLogType: FileUploader.self)

        commiter.commit(draft) { [weak self] result in
            guard let self = self, !self.isCancelled else { return }

            switch result {
            case .success:
                ConsoleLogger.shared?.log("STAGE: 4. Revision committer 📑🔐 finished ✅", osLogType: FileUploader.self)
                self.progress.complete()
                self.state = .finished

            case .failure(let error):
                ConsoleLogger.shared?.log("STAGE: 4. Revision committer 📑🔐 finished ❌", osLogType: FileUploader.self)
                self.onError(error)
            }
        }
    }

    override func cancel() {
        ConsoleLogger.shared?.log("🙅‍♂️ CANCEL \(type(of: self))", osLogType: FileUploader.self)
        commiter.cancel()
        super.cancel()
    }

    var recordingName: String { "commitingRevision" }
}
