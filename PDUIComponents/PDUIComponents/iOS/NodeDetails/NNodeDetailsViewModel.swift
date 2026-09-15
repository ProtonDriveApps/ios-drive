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

public struct NNodeDetailsViewModel {
    let title: String
    let nodeName: String
    let details: [(key: String, value: String)]
    let qaDetails: [(key: String, value: String)]?

    public init(
        title: String,
        nodeName: String,
        details: [(key: String, value: String)],
        qaDetails: [(key: String, value: String)]?
    ) {
        self.title = title
        self.nodeName = nodeName
        self.details = details
        self.qaDetails = qaDetails
    }
}
