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
import ProtonCoreNetworking
import ProtonCoreServices
import ProtonCoreUtilities

// MARK: - Log System for PDClient
public var logInfo: ((String) -> Void)?
public var logError: ((String) -> Void)?

extension PMAPIService: DriveAPIService {
    public func request<E, R>(
        from endpoint: E,
        completionExecutor: CompletionBlockExecutor,
        responseInspectingCompletionBlock: @escaping (Result<R, Error>, HTTPURLResponse?) -> Void
    ) where E: Endpoint, R == E.Response {
        Self.performRequestUsingAPIService(
            apiService: self,
            from: endpoint,
            completionExecutor: completionExecutor,
            responseInspectingCompletionBlock: responseInspectingCompletionBlock
        )
    }
}

extension DriveAPIService {

    /// Canonical helper used by `PMAPIService` and `DriveAPIServiceDelegatingMock`.
    /// Forwards the underlying `URLSessionDataTask`'s `HTTPURLResponse` to the caller
    /// so it can inspect status + headers (e.g. `Retry-After`).
    public static func performRequestUsingAPIService<E, R>(
        apiService: ProtonCoreServices.APIService,
        from endpoint: E,
        completionExecutor: CompletionBlockExecutor,
        responseInspectingCompletionBlock: @escaping (Result<R, Error>, HTTPURLResponse?) -> Void
    ) where E: Endpoint, R == E.Response {
        logInfo?(endpoint.prettyDescription)

        apiService.perform(request: endpoint, callCompletionBlockUsing: completionExecutor) { task, result in
            // The task is delivered alongside the result. Reading `task.response`
            // here is sufficient — we don't need the `onDataTaskCreated` capture
            // pattern (that's only required when the task is needed *before*
            // completion fires, e.g. for cancellation, see
            // `MetadataUpdaterAwareHttpCallExecutor.executeDriveAPICall`).
            let httpResponse = task?.response as? HTTPURLResponse
            let mapped: Result<R, Error> = decode(endpoint: endpoint, result: result)
            responseInspectingCompletionBlock(mapped, httpResponse)
        }
    }

    /// Backwards-compatible variant that drops the `HTTPURLResponse` for callers
    /// that don't need it. Forwards to the canonical helper above.
    public static func performRequestUsingAPIService<E, R>(
        apiService: ProtonCoreServices.APIService,
        from endpoint: E,
        completionExecutor: CompletionBlockExecutor,
        completion: @escaping (Result<R, Error>) -> Void
    ) where E: Endpoint, R == E.Response {
        performRequestUsingAPIService(
            apiService: apiService,
            from: endpoint,
            completionExecutor: completionExecutor
        ) { result, _ in
            completion(result)
        }
    }

    /// Decodes a `Result<JSONDictionary, ResponseError>` (the shape ProtonCore
    /// delivers) into the endpoint's typed `Result<R, Error>`. Behavior matches
    /// the original inline body of `performRequestUsingAPIService` line for line.
    fileprivate static func decode<E, R>(
        endpoint: E, result: Result<JSONDictionary, ResponseError>
    ) -> Result<R, Error> where E: Endpoint, R == E.Response {
        switch result {
        case .failure(let responseError):
            logError?(endpoint.networkingError(responseError))
            return .failure(responseError)

        case .success(let responseDict):
            guard let responseData = try? JSONSerialization.data(withJSONObject: responseDict, options: .prettyPrinted) else {
                logError?(endpoint.unknownError())
                return .failure(URLError(.unknown))
            }

            let decoder = endpoint.decoder
            if let serverError = try? decoder.decode(PDClient.ErrorResponse.self, from: responseData) {
                let error = NSError(serverError)
                logError?(endpoint.serverError(error))
                return .failure(error)
            }

            do {
                let response = try decoder.decode(E.Response.self, from: responseData)
                logInfo?(endpoint.prettyResponse(responseData))
                return .success(response)
            } catch {
                logError?(endpoint.deserializingError(error))
                return .failure(error)
            }
        }
    }
}
