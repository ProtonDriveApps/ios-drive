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

import ProtonCoreNetworking

public protocol CoreAPIService {
    func perform(request route: Request, completion: @escaping (_ task: URLSessionDataTask?, _ result: Result<JSONDictionary, ResponseError>) -> Void)
    func perform(request route: Request, dataTaskBlock: @escaping (URLSessionDataTask) -> Void, completion: @escaping (_ task: URLSessionDataTask?, _ result: Result<JSONDictionary, ResponseError>) -> Void)
}
