// Copyright (c) 2024 Proton AG
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

struct EmailRequest: Request {
    let endpoint: String = "/contacts/v4/contacts/emails"
    let page: Int
    let pageSize: Int
    
    var path: String {
        "\(endpoint)?Page=\(page)&PageSize=\(pageSize)"
    }
    
    init(page: Int = 0, pageSize: Int = 1000) {
        self.page = page
        self.pageSize = pageSize
    }
}
