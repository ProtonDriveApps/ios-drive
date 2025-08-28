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

final class ContentsCreatorOperation: AsynchronousOperation {

    private let id: UUID
    private let contentCreator: ContentCreator
    private let onError: OnUploadError

    init(
        id: UUID,
        contentCreator: ContentCreator,
        onError: @escaping OnUploadError
    ) {
        self.id = id
        self.contentCreator = contentCreator
        self.onError = onError
        super.init()
    }

    override func main() {
        guard !isCancelled else { return }
        
        Log.info("STAGE: 3.0 Content creator 🏞📦☁️ started. UUID: \(id.uuidString)", domain: .uploader)

        contentCreator.create { [weak self] result in
            guard let self = self, !self.isCancelled else { return }

            switch result {
            case .success:
                Log.info("STAGE: 3.0 Content creator 🏞📦☁️ finished ✅. UUID: \(self.id.uuidString)", domain: .uploader)
                self.state = .finished

            case .failure(let error):
                Log.info("STAGE: 3.0 Content creator 🏞📦☁️ finished ❌. UUID: \(self.id.uuidString)", domain: .uploader)
                Log
                    .error(
                        "ContentsCreator create failed",
                        error: error,
                        domain: .uploader,
                        context: LogContext("UUID: \(self.id.uuidString)")
                    )
                self.onError(error)
            }
        }
    }

    override func cancel() {
        contentCreator.cancel()
        super.cancel()
    }
}
