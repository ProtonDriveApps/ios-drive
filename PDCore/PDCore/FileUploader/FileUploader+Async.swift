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

extension Atomic where A == Bool {
    /// Sets the `value` to a new value, returning whether the updated value is different to the previous one.
    ///
    /// You can use this in situations where you want to ensure something is done only once in a thread safe way:
    /// ```
    /// var needToDoSomethingOnlyOnce = Atomic<Bool>(false)
    /// ...
    /// if needToDoSomethingOnlyOnce.changeValue(to: true) {
    ///     doSomething()
    /// }
    /// ```
    ///
    /// Do not be tempted by this pattern instead, as there is a race condition between checking `value` and mutating it.
    /// ```
    /// var needToDoSomethingOnlyOnce = Atomic<Bool>(false)
    /// if !needToDoSomethingOnlyOnce.value {
    ///     needToDoSomethingOnlyOnce.mutate { $0.toggle() }
    ///     doSomething()
    /// }
    /// ```
    /// (This is similar in concept to the "Compare and Swap" pattern in atomics programming.)
    ///
    /// - Note: This should probably belongs Atomic.swift, but that would entail updating Proton Core, so I avoided it for now.
    ///
    /// - Parameter newValue: What `value` should be set to.
    /// - Returns: `true` if  `newValue` was different to the existing `value` and `value` was changed.
    ///            `false` if `value` was already the same as `newValue` and was not changed.
    public func changeValue(to newValue: A) -> Bool {
        var didChange = false
        mutate {
            guard $0 != newValue else { return }
            $0 = newValue
            didChange = true
        }
        return didChange
    }
}

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
                    guard wasContinuationCalled.changeValue(to: true) else { return }
                    continuation.resume(with: $0)
                }
            } catch {
                guard wasContinuationCalled.changeValue(to: true) else { return }
                continuation.resume(with: .failure(error))
            }
        }
    }
    
}
