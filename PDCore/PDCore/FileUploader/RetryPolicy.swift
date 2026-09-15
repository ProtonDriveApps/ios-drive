// Copyright (c) 2026 Proton AG
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

public enum RetryPolicy {
    static let maxAttempts = 3
    
    private static let retryable4xxErrors: Set<Int> = [408]
    public static let retryable5xxErrors: Set<Int> = Set(500...599)
    private static let iosRetryableErrors: Set<Int> = [
        // Custom retry
        iOSDriveRetriableCode
    ]
    private static let internetErrors: Set<Int> = [
        // All handled internet issues
        NSURLErrorTimedOut, // -1001,
        NSURLErrorCannotConnectToHost, // -1004
        NSURLErrorNetworkConnectionLost, // -1005
        NSURLErrorNotConnectedToInternet, // -1009
        NSURLErrorSecureConnectionFailed, // -1200
    ]
    
    private static let decodingErrors: Set<Int> = [
        NSPropertyListReadCorruptError
    ]
    
    static let retryable: Set<Int> = retryable4xxErrors.union(retryable5xxErrors).union(iosRetryableErrors)
    static let retryableIncludingInternetIssues: Set<Int> = retryable.union(internetErrors).union(decodingErrors)
    
    static var iOSDriveRetriableCode: Int {
        321321321 // Just drive iOS specific
    }
}
