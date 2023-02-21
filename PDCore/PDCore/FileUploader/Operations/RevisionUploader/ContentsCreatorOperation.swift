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
import CoreData

final class ContentsCreatorOperation: AsynchronousOperation, OperationWithProgress {

    let progress = Progress(unitsOfWork: 1)

    private let draft: FileDraft
    private let contentCreator: CloudContentCreator
    private let date: () -> Date
    private let onError: OnError

    init(
        draft: FileDraft,
        contentCreator: CloudContentCreator,
        date: @escaping () -> Date = Date.init,
        onError: @escaping OnError
    ) {
        self.draft = draft
        self.contentCreator = contentCreator
        self.date = date
        self.onError = onError
        super.init()
    }

    override func main() {
        guard !isCancelled else { return }

        do {
            let revision = try draft.getUploadableRevision()

            let requestedUploadDate = date()

            contentCreator.create(from: revision) { [weak self] result in
                guard let self = self, !self.isCancelled else { return }

                switch result {
                case .success(let revision):
                    self.finalize(revision, requestedUploadDate)

                case .failure(let error) where (error as NSError).code == Uploader.Errors.noSpaceOnCloudError.code:
                    self.finalizeWithNoSpaceOnCloudError(error)

                case .failure(let error):
                    self.onError(error)
                }
            }
        } catch {
            onError(error)
        }
    }

    private func finalize(_ revision: FullUploadableRevision, _ requestedUploadDate: Date) {
        let file = draft.file
        guard let moc = file.moc else { return onError(File.noMOC()) }

        moc.performAndWait {
            do {
                guard let rev = file.activeRevisionDraft else {
                    throw File.InvalidState(message: "Invalid File, no active revision found for LocalContentCreatorFinalizer")
                }
                let blocks = rev.uploadableUploadBlocks()

                zip(revision.blocks, blocks).forEach { fullUploadableBlock, block in
                    block.uploadToken = fullUploadableBlock.uploadToken
                    block.uploadUrl = fullUploadableBlock.remoteURL.absoluteString
                }

                if let thumbnail = revision.thumbnail  {
                    rev.thumbnail?.uploadURL = thumbnail.uploadURL.absoluteString
                }
                rev.requestedUpload = requestedUploadDate

                try moc.save()

                progress.complete()
                state = .finished

            } catch {
                moc.rollback()
                onError(error)
            }
        }
    }

    private func finalizeWithNoSpaceOnCloudError(_ error: Error) {
        let file = draft.file
        // swiftlint:disable:next todo
        // TODO: Would make sense complete with an error here at all?
        guard let moc = file.moc else { return onError(File.noMOC()) }

        moc.performAndWait {
            do {
                file.state = .waiting
                try moc.save()
            } catch {
                moc.rollback()
            }
            onError(error)
        }
    }
}
