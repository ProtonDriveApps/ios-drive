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
import UnleashProxyClientSwift

public final class UnleashPollerSession: PollerSession {
    private let networking: CoreAPIService

    public init(networking: CoreAPIService) {
        self.networking = networking
    }

    public func perform(_ request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) {
        do {
            let endpoint = UnleashEndpoint(request: request)
            var dataTask: URLSessionDataTask?
            networking.perform(request: endpoint, dataTaskBlock: {
                dataTask = $0
            }, completion: { task, result in
                let response = dataTask?.response ?? task?.response
                switch result {
                case let .success(responseDictionary):
                    do {
                        let data = try JSONSerialization.data(withJSONObject: responseDictionary, options: .prettyPrinted)
                        completionHandler(data, response, nil)
                    } catch {
                        completionHandler(nil, response, error)
                    }
                case let .failure(error):
                    completionHandler(nil, response, error)
                }
            })
        } catch {
            completionHandler(nil, nil, error)
        }
    }
}
