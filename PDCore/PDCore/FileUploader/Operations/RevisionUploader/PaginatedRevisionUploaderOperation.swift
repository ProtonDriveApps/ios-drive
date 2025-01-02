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

final class PaginatedRevisionUploaderOperation: AsynchronousOperation, UploadOperation {

    let id: UUID
    let progress: Progress

    private let draft: FileDraft
    private let uploader: RevisionUploader
    private let onError: OnUploadError
    private var task: Task<Void, Never>?
    
    init(
        draft: FileDraft,
        parentProgress: Progress,
        uploader: RevisionUploader,
        onError: @escaping OnUploadError
    ) {
        self.draft = draft
        self.progress = parentProgress
        self.uploader = uploader
        self.id = draft.uploadID
        self.onError = onError
        super.init()
    }

    override func main() {
        guard !isCancelled else { return }

        record()
        NotificationCenter.default.post(name: .operationStart, object: draft.uri)
        Log.info("STAGE: 3 Upload Revision 🏞📦📝☁️ started. UUID: \(self.id.uuidString)", domain: .uploader)
        task = Task(priority: .userInitiated) { [weak self] in
            guard !Task.isCancelled else { return }
            await self?.performAsynchronously()
        }
    }

    private func performAsynchronously() async {
        do {
            let verification = try await uploader.prepareVerification(draft)
            uploader.upload(draft, verification: verification) { [weak self] result in
                guard let self = self, !self.isCancelled else { return }

                switch result {
                case .success:
                    Log.info("STAGE: 3 Upload Revision 🏞📦📝☁️ finished ✅. UUID: \(self.id.uuidString)", domain: .uploader)
                    NotificationCenter.default.post(name: .operationEnd, object: draft.uri)
                    #if os(iOS)
                    self.progress.complete()
                    #endif
                    self.state = .finished

                case .failure(let error):
                    Log.info("STAGE: 3 Upload Revision 🏞📦📝☁️ finished ❌. UUID: \(self.id.uuidString)", domain: .uploader)
                    NotificationCenter.default.post(name: .operationEnd, object: draft.uri)
                    self.onError(error)
                }
            }
        } catch {
            Log.info("STAGE: 3 Upload Revision 🏞📦📝☁️ finished ❌. UUID: \(self.id.uuidString)", domain: .uploader)
            NotificationCenter.default.post(name: .operationEnd, object: draft.uri)
            onError(error)
        }
    }

    override func cancel() {
        Log.info("STAGE: 3 🙅‍♂️ CANCEL \(type(of: self)). UUID: \(id.uuidString)", domain: .uploader)
        NotificationCenter.default.post(name: .operationEnd, object: draft.uri)
        task?.cancel()
        task = nil
        uploader.cancel()
        super.cancel()
    }

    var recordingName: String { "uploadingRevision" }

    deinit {
        task = nil
        Log.info("STAGE: 3 ☠️🚨 \(type(of: self)). UUID: \(id.uuidString)", domain: .uploader)
    }
}
