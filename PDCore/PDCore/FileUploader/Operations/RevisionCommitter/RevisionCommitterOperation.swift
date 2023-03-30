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

    let uploadID: UUID
    let progress = Progress(unitsOfWork: 1)

    private let draft: FileDraft
    private let sealer: RevisionSealer
    private let failedMarker: FailedUploadMarker
    private let onError: OnError

    init(
        draft: FileDraft,
        sealer: RevisionSealer,
        failedMarker: FailedUploadMarker,
        onError: @escaping OnError
    ) {
        self.draft = draft
        self.sealer = sealer
        self.failedMarker = failedMarker
        self.uploadID = draft.uploadID
        self.onError = onError
        super.init()
    }

    static var blocksUploadedWronglyErrorCode: Int { 2000 }

    override func main() {
        guard !isCancelled else { return }

        record()
        executeRemoteSeal()
    }

    private func executeRemoteSeal() {
        do {
            ConsoleLogger.shared?.log("STAGE: 4. Revision sealer 📑🔐 started", osLogType: FileUploader.self)
            let revision = try draft.getSealableRevision()
            let revisionURI = revision.objectID.uriRepresentation()
            let data = try sealer.makeData(revision: revision)
            sealer.sealRemote(data: data) { [weak self] result in
                self?.handleRemoteSeal(result: result, data: data, revisionURI: revisionURI)
            }
        } catch {
            handleError(error)
        }
    }

    private func handleRemoteSeal(result: Result<Void, Error>, data: RevisionSealData, revisionURI: URL) {
        guard !self.isCancelled else { return }
        
        switch result {
        case .success:
            executeLocalSeal(data: data, revisionURI: revisionURI)
        case .failure(let error as NSError) where error.code == Self.blocksUploadedWronglyErrorCode:
            ConsoleLogger.shared?.log("STAGE: 4. Revision sealer 📑🔐 finished ❌", osLogType: FileUploader.self)
            rollbackUploadedStatus(revisionURI: revisionURI)
            onError(error)
        case .failure(let error):
            handleError(error)
        }
    }

    private func executeLocalSeal(data: RevisionSealData, revisionURI: URL) {
        do {
            try sealer.sealLocal(data: data, revisionURI: revisionURI)
            ConsoleLogger.shared?.log("STAGE: 4. Revision sealer 📑🔐 finished ✅", osLogType: FileUploader.self)
            progress.complete()
            state = .finished
        } catch {
            handleError(error)
        }
    }

    private func handleError(_ error: Error) {
        ConsoleLogger.shared?.log("STAGE: 4. Revision sealer 📑🔐 finished ❌", osLogType: FileUploader.self)
        onError(error)
    }

    private func rollbackUploadedStatus(revisionURI: URL) {
        failedMarker.rollbackUploadedStatus(revisionURI: revisionURI)
    }

    var recordingName: String { "commitingRevision" }
}

protocol FailedUploadMarker {
    func rollbackUploadedStatus(revisionURI: URL)
}

extension StorageManager: FailedUploadMarker {

    func rollbackUploadedStatus(revisionURI: URL) {
        backgroundContext.performAndWait {
            guard let revision: Revision = backgroundContext.existingObject(with: revisionURI) else {
                return
            }
            revision.uploadState = .encrypted
            revision.blocks.compactMap { $0 as? UploadBlock }.forEach { $0.isUploaded = false }

            try? backgroundContext.save()
        }
    }

}
