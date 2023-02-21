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

final class RevisionSealerOperation: AsynchronousOperation, OperationWithProgress {

    let progress = Progress(unitsOfWork: 1)

    private let draft: FileDraft
    private let sealer: RevisionSealer
    private let failedMarker: FailedUploadMarker
    private let onError: OnError

    init(draft: FileDraft, sealer: RevisionSealer, failedMarker: FailedUploadMarker, onError: @escaping OnError) {
        self.draft = draft
        self.sealer = sealer
        self.failedMarker = failedMarker
        self.onError = onError
        super.init()
    }

    static var blocksUploadedWronglyErrorCode: Int { 2000 }

    override func main() {
        guard !isCancelled else { return }

        do {
            ConsoleLogger.shared?.log("STAGE: 4. Revision sealer 📑🔐 started", osLogType: FileUploader.self)
            let revision = try draft.getSealableRevision()

            sealer.seal(revision: revision) { [weak self] result in
                guard let self = self, !self.isCancelled else { return }

                switch result {
                case .success:
                    ConsoleLogger.shared?.log("STAGE: 4. Revision sealer 📑🔐 finished ✅", osLogType: FileUploader.self)
                    self.progress.complete()
                    self.state = .finished
                    self.draft.state = .finished

                case .failure(let error as NSError) where error.code == Self.blocksUploadedWronglyErrorCode:
                    ConsoleLogger.shared?.log("STAGE: 4. Revision sealer 📑🔐 finished ❌", osLogType: FileUploader.self)
                    self.rollbackUploadedStatus(revision: revision)
                    self.onError(error)

                case .failure(let error):
                    ConsoleLogger.shared?.log("STAGE: 4. Revision sealer 📑🔐 finished ❌", osLogType: FileUploader.self)
                    self.onError(error)
                }
            }

        } catch {
            ConsoleLogger.shared?.log("STAGE: 4. Revision sealer 📑🔐 finished ❌", osLogType: FileUploader.self)
            onError(error)
        }
    }

    private func rollbackUploadedStatus(revision: Revision) {
        failedMarker.rollbackUploadedStatus(revision: revision)
    }
}

protocol FailedUploadMarker {
    func rollbackUploadedStatus(revision: Revision)
}

extension StorageManager: FailedUploadMarker {

    func rollbackUploadedStatus(revision: Revision) {
        backgroundContext.performAndWait {
            let revision = revision.in(moc: backgroundContext)
            revision.uploadState = .encrypted
            revision.blocks.compactMap { $0 as? UploadBlock }.forEach { $0.isUploaded = false }

            try? backgroundContext.save()
        }
    }

}
