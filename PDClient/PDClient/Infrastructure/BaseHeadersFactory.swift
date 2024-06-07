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

public protocol BaseHeadersFactory {
    func makeHeaders() -> [String: String]
}

public final class DriveBaseHeadersFactory: BaseHeadersFactory {
    private let configuration: APIService.Configuration

    public init(configuration: APIService.Configuration) {
        self.configuration = configuration
    }

    public func makeHeaders() -> [String: String] {
        [
            "x-pm-appversion": configuration.clientVersion,
            "Accept": "application/vnd.protonmail.v1+json",
            "Content-Type": "application/json;charset=utf-8"
        ]
    }
}
