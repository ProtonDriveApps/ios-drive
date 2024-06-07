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

public class FileUploaderOperation: AsynchronousOperation, UploadOperation {

    public let progress = Progress(unitsOfWork: 1)
    public let id: UUID

    private let draft: FileDraft
    private let onSuccess: OnUploadSuccess

    init(draft: FileDraft, onSuccess: @escaping OnUploadSuccess) {
        self.id = draft.uploadID
        self.draft = draft
        self.onSuccess = onSuccess
        super.init()
    }

    override public func main() {
        guard !isCancelled else { return }

        record()

        Log.info("STAGE: 5 🎉🎉🎉🎉  Completed File Upload, id: \(id.uuidString) 🎉🎉🎉🎉", domain: .uploader)
        NotificationCenter.default.post(name: .didUploadFile)
        progress.complete()
        state = .finished
        onSuccess(draft.file)
    }

    func pauseUpload() {
        cancel()
        draft.file.changeUploadingState(to: .paused)
        draft.file.makeUploadableAgain()
    }
    
    func interrupt() {
        cancel()
        draft.file.changeUploadingState(to: .interrupted)
        draft.file.makeUploadableAgain()
    }

    override public func cancel() {
        Log.info("STAGE: 5 🙅‍♂️ CANCEL \(type(of: self)). UUID: \(id.uuidString)", domain: .uploader)
        super.cancel()
        draft.file.moc?.perform {
            self.draft.file.isUploading = false
        }
        dependencies.reversed().forEach { $0.cancel() }
        progress.cancel()
    }

    public func cancelForRetry() {
        Log.info("STAGE: 5 🙅‍♂️ CANCEL FOR RETRY \(type(of: self)). UUID: \(id.uuidString)", domain: .uploader)
        super.cancel()
        dependencies.reversed().forEach { $0.cancel() }
        progress.cancel()
    }

    deinit {
        Log.info("STAGE: 5 ☠️🚨 \(type(of: self)). UUID: \(id.uuidString)", domain: .uploader)
        NotificationCenter.default.post(name: .uploadPendingPhotos)
    }

    public var recordingName: String { "uploadedFile" }
}
