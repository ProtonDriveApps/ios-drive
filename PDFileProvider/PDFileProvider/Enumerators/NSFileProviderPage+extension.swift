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

import FileProvider
import PDCore

public extension NSFileProviderPage {
    init(_ int: Int) {
        Log.trace()
        let pageData = withUnsafeBytes(of: (int)) { Data($0) }
        self.init(rawValue: pageData)
    }

    var int: Int {
        if rawValue == NSFileProviderPage.initialPageSortedByDate as Data ||
           rawValue == NSFileProviderPage.initialPageSortedByName as Data {
            return 0
        } else {
            return rawValue.withUnsafeBytes { $0.load(as: Int.self) }
        }
    }
}
