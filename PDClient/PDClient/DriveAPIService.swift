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
import ProtonCoreServices

/// DriveAPIService:
/// Protocol that will allow us to decouple from Core's statically defined APIService and implement polymorphisim in a clean way.
public protocol DriveAPIService {
    var authDelegate: AuthDelegate? { get }

    /// Canonical request method. Delivers the typed `Result` *and* the underlying
    /// `HTTPURLResponse` (when available) so the caller can inspect status + headers
    /// (e.g. `Retry-After`). The legacy `request(from:completionExecutor:completion:)`
    /// form is provided as a default implementation that drops the response.
    func request<E: Endpoint, R>(
        from endpoint: E,
        completionExecutor: CompletionBlockExecutor,
        responseInspectingCompletionBlock: @escaping (Result<R, Error>, HTTPURLResponse?) -> Void
    ) where R == E.Response
}

public extension DriveAPIService {
    /// Legacy convenience: same behavior as the canonical `responseInspectingCompletionBlock` variant
    /// but discards the `HTTPURLResponse`. Kept so existing callers don't need to change.
    func request<E: Endpoint, R>(
        from endpoint: E,
        completionExecutor: CompletionBlockExecutor,
        completion: @escaping (Result<R, Error>) -> Void
    ) where R == E.Response {
        request(from: endpoint, completionExecutor: completionExecutor) { result, _ in
            completion(result)
        }
    }
}
