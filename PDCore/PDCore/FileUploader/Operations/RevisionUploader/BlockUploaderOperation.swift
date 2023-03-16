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

    var progress: Progress

    private let draft: FileDraft
    private let blockIndex: Int
    private let contentUploader: ContentUploader
    private let now: () -> Date
    private let onError: OnError

    private let logger: ConsoleLogger?

    init(
        draft: FileDraft,
        progressTracker: Progress,
        blockIndex: Int,
        contentUploader: ContentUploader,
        now: @escaping () -> Date = Date.init,
        onError: @escaping OnError
    ) {
        self.draft = draft
        self.progress = progressTracker
        self.blockIndex = blockIndex
        self.contentUploader = contentUploader
        self.now = now
        self.onError = onError
        logger = ConsoleLogger.shared
        super.init()
    }

    override func main() {
        guard !isCancelled else { return }
        logger?.log("STAGE: 3.2 Block \(blockIndex) upload 📦☁️ started", osLogType: FileUploader.self)

        do {
            // We keep requesting the model to check the consistency of the state
            let _ = try draft.getRequestedUploadForActiveRevisionDraft()

            // But now we continue regardless of the presumed link expiration time
            attemptUpload()

        } catch {
            onError(error)
        }
    }

    private func attemptUpload() {
        let onCompletion: (Result<Void, Error>) -> Void = { [weak self, blockIndex] result in
            guard let self = self, !self.isCancelled else { return }

            switch result {
            case .success:
                self.logger?.log("STAGE: 3.2 Block \(blockIndex) upload 📦☁️ finished ✅", osLogType: FileUploader.self)
                self.progress.complete()
                self.saveUploadedBlockState()

            case .failure(let error) where (error as NSError).code == Uploader.Errors.noSpaceOnCloudError.code:
                self.logger?.log("STAGE: 3.2 Block \(blockIndex) upload 📦☁️ finished ❌ - No space on cloud ", osLogType: FileUploader.self)
                self.finalizeWithNoSpaceOnCloudError(error)

            case .failure(let error):
                self.logger?.log("STAGE: 3.2 Block \(blockIndex) upload 📦☁️ finished ❌", osLogType: FileUploader.self)
                self.onError(error)
            }
        }
        contentUploader.onCompletion = onCompletion

        contentUploader.upload()
    }

    private func saveUploadedBlockState() {
        let file = draft.file
        guard let moc = file.moc else { return onError(File.noMOC()) }

        moc.performAndWait {
            do {
                guard let revision = file.activeRevisionDraft else {
                    throw file.invalidState("No activeRevisionDraft found")
                }

                guard let block = revision.blocks.first(where: { $0.index == blockIndex }) else {
                    throw revision.invalidState("No Block with index: \(blockIndex) found")
                }

                guard let block = block as? UploadBlock else {
                    throw block.invalidState("Could not cast Block with index: \(blockIndex) as UploadBlock ")
                }

                block.isUploaded = true

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
                file.state = .cloudImpediment
                try moc.save()
            } catch {
                moc.rollback()
            }
            onError(error)
        }
    }

    override func cancel() {
        ConsoleLogger.shared?.log("🙅‍♂️🙅‍♂️🙅‍♂️🙅‍♂️ CANCEL \(type(of: self))", osLogType: FileUploader.self)
        super.cancel()
        progress.complete()
    }
}
