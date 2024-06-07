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

final class RevisionDraftCreatorOperation: AsynchronousOperation, UploadOperation {

    let id: UUID
    let progress: Progress = Progress(unitsOfWork: 1)
    let draft: FileDraft
    let creator: RevisionDraftCreator
    let onError: OnUploadError

    init(
        draft: FileDraft,
        creator: RevisionDraftCreator,
        onError: @escaping OnUploadError
    ) {
        self.id = draft.uploadID
        self.draft = draft
        self.creator = creator
        self.onError = onError
        super.init()
    }

    override func main() {
        guard !isCancelled else { return }

        Log.info("STAGE: 1 Create revision 🐣📦🏞 started. UUID: \(self.id.uuidString)", domain: .uploader)
        creator.create(draft) { [weak self] result in
            guard let self = self, !self.isCancelled else { return }

            switch result {
            case .success:
                Log.info("STAGE: 1 Create revision 🐣📦🏞 finished ✅. UUID: \(self.id.uuidString)", domain: .uploader)
                self.progress.complete()
                self.state = .finished

            case .failure(let error):
                Log.info("STAGE: 1 Create revision 🐣📦🏞 finished ❌. UUID: \(self.id.uuidString)", domain: .uploader)
                self.onError(error)
            }
        }
    }

    override func cancel() {
        Log.info("STAGE: 1 🙅‍♂️ CANCEL \(type(of: self)). UUID: \(id.uuidString)", domain: .uploader)
        creator.cancel()
        super.cancel()
    }

    deinit {
        Log.info("STAGE: 1 ☠️🚨 \(type(of: self)). UUID: \(id.uuidString)", domain: .uploader)
    }
}
