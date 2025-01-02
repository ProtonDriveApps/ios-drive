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
import ProtonCoreServices
import ProtonCoreUtilities

// MARK: - Log System for PDClient
public var log: ((String) -> Void)?

extension PMAPIService: DriveAPIService {
    public func request<E, Response>(from endpoint: E, completionExecutor: CompletionBlockExecutor, completion: @escaping (Result<Response, Error>) -> Void) where E: Endpoint, Response == E.Response {
        Self.performRequestUsingAPIService(apiService: self, from: endpoint, completionExecutor: completionExecutor, completion: completion)
    }
}

extension DriveAPIService {
    
    public static func performRequestUsingAPIService<E, Response>(
        apiService: ProtonCoreServices.APIService,
        from endpoint: E,
        completionExecutor: CompletionBlockExecutor,
        completion: @escaping (Result<Response, Error>) -> Void
    ) where E: Endpoint, Response == E.Response {
        log?(endpoint.prettyDescription)
        
        apiService.perform(request: endpoint, callCompletionBlockUsing: completionExecutor) { task, result in
            switch result {
            case .failure(let responseError):
                log?(endpoint.networkingError(responseError))
                return completion(.failure(responseError))

            case .success(let responseDict):
                guard let responseData = try? JSONSerialization.data(withJSONObject: responseDict, options: .prettyPrinted) else {
                    log?(endpoint.unknownError())
                    return completion(.failure(URLError(.unknown)))
                }

                let decoder = endpoint.decoder
                if let serverError = try? decoder.decode(PDClient.ErrorResponse.self, from: responseData) {
                    let error = NSError(serverError)
                    log?(endpoint.serverError(error))
                    return completion(.failure(error))
                }

                do {
                    let response = try decoder.decode(E.Response.self, from: responseData)
                    log?(endpoint.prettyResponse(responseData))
                    return completion(.success(response))
                } catch {
                    log?(endpoint.deserializingError(error))
                    return completion(.failure(error))
                }
            }
        }
    }
}
