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

final class RevisionEncryptionOperation: AsynchronousOperation, UploadOperation {

    private let draft: FileDraft
    private let revisionEncryptor: RevisionEncryptor
    private let onError: OnUploadError

    let progress: Progress
    let id: UUID

    init(
        progress: Progress,
        draft: FileDraft,
        revisionEncryptor: RevisionEncryptor,
        onError: @escaping OnUploadError
    ) {
        self.progress = progress
        self.draft = draft
        self.revisionEncryptor = revisionEncryptor
        self.onError = onError
        self.id = draft.uploadID
        super.init()
    }

    override func main() {
        guard !isCancelled else { return }

        record()

        ConsoleLogger.shared?.log("STAGE: 2 🏞📦 Encrypt revision started", osLogType: FileUploader.self)

        // TODO: Empty files should have their own RevisionEncryptor subclass
        guard !draft.isEmpty else {
            ConsoleLogger.shared?.log("STAGE: 2 🏞📦 Encrypt revision finished ✅", osLogType: FileUploader.self)
            state = .finished
            progress.complete()
            return
        }

        ConsoleLogger.shared?.log("STAGE: 2 🏞📦 Encrypt revision started", osLogType: FileUploader.self)
        do {
            let revisionDraft = try draft.getCreatedRevisionDraft()
            revisionEncryptor.encrypt(revisionDraft) { [weak self] result in
                guard let self = self, !self.isCancelled else { return }

                switch result {
                case .success:
                    ConsoleLogger.shared?.log("STAGE: 2 🏞📦 Encrypt revision finished ✅", osLogType: FileUploader.self)
                    self.progress.complete()
                    self.state = .finished

                case .failure(let error):
                    ConsoleLogger.shared?.log("STAGE: 2 🏞📦 Encrypt revision finished ❌", osLogType: FileUploader.self)
                    self.onError(error)
                }
            }
        } catch {
            ConsoleLogger.shared?.log("STAGE: 2 🏞📦 Encrypt revision finished ❌", osLogType: FileUploader.self)
            onError(error)
        }
    }

    override func cancel() {
        ConsoleLogger.shared?.log("🙅‍♂️ CANCEL \(type(of: self))", osLogType: FileUploader.self)
        revisionEncryptor.cancel()
        super.cancel()
    }

    var recordingName: String { "encryptingRevision" }
}
