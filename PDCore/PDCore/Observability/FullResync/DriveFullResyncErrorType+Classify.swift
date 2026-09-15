// Copyright (c) 2025 Proton AG
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
import ProtonCoreNetworking
import ProtonCoreServices

public extension DriveFullResyncErrorType {
    // NSCocoaErrorDomain Core Data code ranges (CoreDataErrors.h): validation 1550–1680, object graph
    // 132000–133021 (context locking, referential integrity, merge/constraint conflicts), persistent store 134000–134999.
    private static let coreDataValidationCodes = 1550...1680
    private static let coreDataObjectGraphCodes = 132000...133021
    private static let coreDataPersistentStoreCodes = 134000...134999

    /// Maps a full-resync stopping error to the `errors_total` type dimension. Order matters: the more
    /// specific local/domain failures are checked before the generic HTTP / network / Core Data buckets.
    static func classify(_ error: Error) -> DriveFullResyncErrorType {
        if error is BackupAndRestoreDBErrors {
            return .dbFiles
        }
        if let domainError = error as? DomainOperationErrors, case .signalEnumeratorFailed = domainError {
            return .signaling
        }
        if let httpCode = (error as? ResponseError)?.httpCode {
            if (500..<600).contains(httpCode) { return .fivexx }
            if (400..<500).contains(httpCode) { return .fourxx }
        }
        if isNetworkError(error) {
            return .network
        }
        let nsError = error as NSError
        let isCoreDataCode = Self.coreDataValidationCodes.contains(nsError.code)
            || Self.coreDataObjectGraphCodes.contains(nsError.code)
            || Self.coreDataPersistentStoreCodes.contains(nsError.code)
        if nsError.domain == NSCocoaErrorDomain, isCoreDataCode {
            return .coreData
        }
        return .unknown
    }

    /// Network connectivity failures: URL errors, Proton "API blocked" / network-issue responses, or any of
    /// those wrapped inside a ResponseError or an NSError's underlying errors.
    private static func isNetworkError(_ error: Error) -> Bool {
        if let responseError = error as? ResponseError {
            if responseError.isApiIsBlockedError || responseError.isNetworkIssueError { return true }
            if let underlying = responseError.underlyingError { return isNetworkError(underlying) }
            return false
        }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain { return true }
        return nsError.underlyingErrors.contains { isNetworkError($0) }
    }
}
