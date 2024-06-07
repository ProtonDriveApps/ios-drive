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

class ImmediatelyFinishingOperation: AsynchronousOperation, OperationWithProgress, UploadOperation {
    let id: UUID
    let progress = Progress(unitsOfWork: 1)

    init(id: UUID? = nil) {
        self.id = id ?? UUID()
        super.init()
    }

    override func main() {
        guard !isCancelled else { return }
        progress.complete()
        state = .finished
        Log.info("STAGE: 0 💨 \(type(of: self)). UUID: \(id)", domain: .uploader)
    }

    override public func cancel() {
        Log.info("STAGE: 0 🙅‍♂️ CANCEL \(type(of: self)). UUID: \(id.uuidString)", domain: .uploader)
        super.cancel()
    }

    deinit {
        Log.info("STAGE: 0 ☠️🚨 \(type(of: self)). UUID: \(id.uuidString)", domain: .uploader)
        NotificationCenter.default.post(name: .uploadPendingPhotos)
    }
}
