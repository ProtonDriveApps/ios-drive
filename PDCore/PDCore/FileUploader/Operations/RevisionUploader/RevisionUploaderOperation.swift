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

final class RevisionUploaderOperation: AsynchronousOperation, OperationWithProgress {

    let progress: Progress

    private let draft: FileDraft
    private let uploader: RevisionOperationsProcessor
    private let onError: OnError

    private var logger: ConsoleLogger?

    init(
        draft: FileDraft,
        progress: Progress,
        uploader: RevisionOperationsProcessor,
        onError: @escaping OnError
    ) {
        self.draft = draft
        self.progress = progress
        self.uploader = uploader

        let loger = ConsoleLogger.shared
        self.logger = loger
        self.onError = { error in
            loger?.log("STAGE: 3 Upload Revision 🏞📦☁️ finished ❌", osLogType: FileUploader.self)
            onError(error)
        }
        super.init()
    }

    override func main() {
        guard !isCancelled else { return }

        logger?.log("STAGE: 3 Upload Revision 🏞📦☁️ started", osLogType: FileUploader.self)

        // swiftlint:disable:next todo
        // TODO: Improve this in order not to have flow control statements all over the place
        guard !draft.isEmpty else {
            ConsoleLogger.shared?.log("STAGE: 3 Upload Revision 🏞📦☁️ finished ✅", osLogType: FileUploader.self)
            finalizeRevision()
            progress.complete()
            state = .finished
            return
        }

        uploader.didFinish = { [weak self] in
            guard let self = self, !self.isCancelled else { return }
            self.logger?.log("STAGE: 3 Upload Revision 🏞📦☁️ finished ✅", osLogType: FileUploader.self)
            self.finalizeRevision()
        }

        uploader.process()
    }

    func finalizeRevision() {
        let file = draft.file
        guard let moc = file.moc else { return onError(File.noMOC()) }

        moc.performAndWait {
            do {
                guard let revision = file.activeRevisionDraft else {
                    throw file.invalidState("No activeRevisionDraft found")
                }
                revision.uploadState = .uploaded

                try moc.save()

                draft.state = .sealingRevision
                progress.complete()
                state = .finished

            } catch {
                moc.rollback()
                onError(error)
            }
        }
    }

    override func cancel() {
        ConsoleLogger.shared?.log("🙅‍♂️🙅‍♂️🙅‍♂️🙅‍♂️ CANCEL \(type(of: self))", osLogType: FileUploader.self)
        super.cancel()
        progress.cancel()
    }

}
