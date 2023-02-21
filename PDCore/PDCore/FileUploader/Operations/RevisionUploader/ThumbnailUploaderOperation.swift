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

final class ThumbnailUploaderOperation: AsynchronousOperation {

    private let progressTracker: Progress
    private let draft: FileDraft
    private let contentUploader: ContentUploader

    init(
        draft: FileDraft,
        progressTracker: Progress,
        contentUploader: ContentUploader
    ) {
        self.draft = draft
        self.progressTracker = progressTracker
        self.contentUploader = contentUploader
        super.init()
    }

    override func main() {
        guard !isCancelled else { return }

        ConsoleLogger.shared?.log("STAGE: 3.1 Thumbnail upload 🏞☁️ started", osLogType: FileUploader.self)

        let onCompletion: (Result<Void, Error>) -> Void = { [weak self] result in
            guard let self = self, !self.isCancelled else { return }

            switch result {
            case .success:
                ConsoleLogger.shared?.log("STAGE: 3.1 Thumbnail upload 🏞☁️ finished ✅", osLogType: FileUploader.self)
                self.finalizeThumbnailUpload()
            case .failure:
                ConsoleLogger.shared?.log("STAGE: 3.1 Thumbnail upload 🏞☁️ finished ❌", osLogType: FileUploader.self)
            }

            self.progressTracker.complete()
            self.state = .finished
        }
        contentUploader.onCompletion = onCompletion

        contentUploader.upload()
    }

    private func finalizeThumbnailUpload() {
        let file = draft.file
        guard let moc = file.moc else { return }

        moc.performAndWait {
            guard let revision = file.activeRevisionDraft,
                  let thumbnail = revision.thumbnail else { return }

            thumbnail.isUploaded = true

            try? moc.save()
        }
    }

    override func cancel() {
        ConsoleLogger.shared?.log("🙅‍♂️🙅‍♂️🙅‍♂️🙅‍♂️ CANCEL \(type(of: self))", osLogType: FileUploader.self)
        super.cancel()
        progressTracker.cancel()
    }

}
