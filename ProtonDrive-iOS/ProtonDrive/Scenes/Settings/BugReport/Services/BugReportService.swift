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
import ProtonCoreServices
import PDClient
import ProtonCoreNetworking

protocol BugReportServiceProtocol {
    func reportBug(_ report: BugReport) async throws
}

final class BugReportService: BugReportServiceProtocol {
    private let apiService: PMAPIService

    init(api: PMAPIService) {
        self.apiService = api
    }

    func reportBug(_ report: BugReport) async throws {
        let request = ReportsBugsEndpoint(report)

        let files: [String: URL] = report.files.reduce(into: [:]) { $0[$1.lastPathComponent] = $1 }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            apiService.performUpload(
                request: request,
                files: files,
                callCompletionBlockUsing: .immediateExecutor,
                uploadProgress: nil
            ) { task, result in
                if let error = task?.error ?? result.error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

extension Result {
    var error: Error? {
        guard case let .failure(error) = self else { return nil }
        return error
    }

    var nsError: NSError? {
        error as NSError?
    }
}
