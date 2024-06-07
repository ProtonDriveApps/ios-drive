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

final class ContentRevisionEncryptorOperation: AsynchronousOperation {

    private let revision: CreatedRevisionDraft
    private let contentEncryptor: RevisionEncryptor
    private let onError: OnUploadError

    init(
        revision: CreatedRevisionDraft,
        contentEncryptor: RevisionEncryptor,
        onError: @escaping OnUploadError
    ) {
        self.revision = revision
        self.contentEncryptor = contentEncryptor
        self.onError = onError
        super.init()
    }

    override func main() {
        contentEncryptor.encrypt(revision) { [weak self] result in
            guard let self = self, !self.isCancelled else { return }

            switch result {
            case .success:
                self.state = .finished

            case .failure(let error):
                self.onError(error)
                self.state = .finished
            }
        }
    }

    override func cancel() {
        Log.info("🙅‍♂️🙅‍♂️ CANCEL \(type(of: self))", domain: .uploader)
        contentEncryptor.cancel()
        super.cancel()
    }
}
