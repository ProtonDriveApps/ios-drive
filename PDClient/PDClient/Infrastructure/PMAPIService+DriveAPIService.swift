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

import ProtonCore_Services
import os.log

// MARK: - Log System for PDClient
private let logger: OSLog = OSLog(subsystem: "PDClient", category: "Client")

private func log(_ message: String) {
    os_log("%{public}@", log: logger, type: .default, message)
}

extension PMAPIService: DriveAPIService {

    public func request<E, Response>(from endpoint: E, completion: @escaping (Result<Response, Error>) -> Void) where E: Endpoint, Response == E.Response {
        log(endpoint.prettyDescription)

        perform(request: endpoint) { task, result in
            switch result {
            case .failure(let responseError):
                log(endpoint.networkingError(responseError))
                return completion(.failure(responseError))

            case .success(let responseDict):
                guard let responseData = try? JSONSerialization.data(withJSONObject: responseDict, options: .prettyPrinted) else {
                    log(endpoint.unknownError())
                    return completion(.failure(URLError(.unknown)))
                }

                let decoder = JSONDecoder(strategy: .decapitaliseFirstLetter)
                if let serverError = try? decoder.decode(PDClient.ErrorResponse.self, from: responseData) {
                    let error = NSError(serverError)
                    log(endpoint.serverError(error))
                    return completion(.failure(error))
                }

                do {
                    let response = try decoder.decode(E.Response.self, from: responseData)
                    log(endpoint.prettyResponse(responseData))
                    return completion(.success(response))
                } catch {
                    log(endpoint.deserializingError(error))
                    return completion(.failure(error))
                }
            }
        }
    }
}
