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

final class MainFileUploaderOperation: AsynchronousOperation, UploadOperation {

    let progress = Progress(unitsOfWork: 1)
    let uploadID: UUID

    private let draft: FileDraft
    private let onSuccess: OnUploadSuccess

    init(draft: FileDraft, onSuccess: @escaping OnUploadSuccess) {
        self.uploadID = draft.uploadID
        self.draft = draft
        self.onSuccess = onSuccess
        super.init()
    }

    override func main() {
        guard !isCancelled else { return }

        ConsoleLogger.shared?.log("🎉🎉🎉🎉  Completed File Upload, id: \(uploadID.uuidString) 🎉🎉🎉🎉", osLogType: FileUploader.self)
        progress.complete()
        state = .finished
        onSuccess(draft)
    }

    func pause() {
        cancel()
        guard let moc = draft.file.managedObjectContext else { return }
        moc.performAndWait {
            draft.file.state = .pausedUpload
            try? moc.save()
        }
    }

    override func cancel() {
        super.cancel()
        dependencies.reversed().forEach { $0.cancel() }
        progress.cancel()
    }

}
