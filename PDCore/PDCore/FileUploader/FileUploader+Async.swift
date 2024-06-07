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
import ProtonCoreUtilities

extension FileUploader {
    
    @discardableResult
    public func upload(_ file: File) async throws -> File {
        try await withCheckedThrowingContinuation { continuation in
            // The reason for guarding the continuation with a flag is as follows:
            //
            // We perform the upload in blocks, parallelly. Each upload is done in a separate operation.
            // In case there is an error, the operations are cancelled, and the error is returned to the continuation.
            // However, because the isCancelled property in the NSOperation is just a bool that you need to
            // check yourselves (also, not thread-safe), there's a possibility that the operation will try to
            // perform a call (or fetch credentials) after it'd been cancelled, returning the error
            // and calling the continuation for the second time.
            // The continuation API is very strict and will crash the extension at this point.
            // We want to avoid that, hence the additional flag for ensuring the continuation is called only once.
            //
            // Note: The above scenario was observed and reproduced a few times by signing the user out during the upload.
            let wasContinuationCalled = Atomic<Bool>(false)
            do {
                try uploadFile(file) {
                    guard !wasContinuationCalled.value else { return }
                    wasContinuationCalled.mutate { $0.toggle() }
                    continuation.resume(with: $0)
                }
            } catch {
                guard !wasContinuationCalled.value else { return }
                wasContinuationCalled.mutate { $0.toggle() }
                continuation.resume(with: .failure(error))
            }
        }
    }
    
}
