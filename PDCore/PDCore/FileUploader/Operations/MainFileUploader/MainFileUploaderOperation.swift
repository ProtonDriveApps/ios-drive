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

public final class MainFileUploaderOperation: AsynchronousOperation, UploadOperation {

    public let progress = Progress(unitsOfWork: 1)
    public let id: UUID

    private let draft: FileDraft
    private let onSuccess: (File) -> Void

    init(draft: FileDraft, onSuccess: @escaping (File) -> Void) {
        self.id = draft.uploadID
        self.draft = draft
        self.onSuccess = onSuccess
        super.init()
    }

    override public func main() {
        guard !isCancelled else { return }

        record()

        ConsoleLogger.shared?.log("🎉🎉🎉🎉  Completed File Upload, id: \(id.uuidString) 🎉🎉🎉🎉", osLogType: FileUploader.self)
        progress.complete()
        state = .finished
        onSuccess(draft.file)
    }

    func pause() {
        cancel(with: .paused)
    }
    
    func interrupt() {
        cancel(with: .interrupted)
    }
    
    private func cancel(with state: Node.State) {
        cancel()
        guard let moc = draft.file.managedObjectContext else { return }
        moc.performAndWait {
            draft.file.state = state
            try? moc.save()
        }
    }

    override public func cancel() {
        ConsoleLogger.shared?.log("🙅‍♂️ CANCEL \(type(of: self))", osLogType: FileUploader.self)
        super.cancel()
        dependencies.reversed().forEach { $0.cancel() }
        progress.cancel()
    }

    public var recordingName: String { "uploadedFile" }
}
