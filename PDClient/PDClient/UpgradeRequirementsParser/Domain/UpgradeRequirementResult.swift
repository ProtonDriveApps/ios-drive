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

public final class UpgradeRequirementResult: Equatable {
    /// update required products
    public private(set) var updateRequired: [String] = []
    /// update recommended products
    public private(set) var updateRecommended: [String] = []
    
    var hasAnyUpdate: Bool { !updateRequired.isEmpty || !updateRecommended.isEmpty }
    
    public static func == (lhs: UpgradeRequirementResult, rhs: UpgradeRequirementResult) -> Bool {
        lhs.updateRequired.sorted() == rhs.updateRequired.sorted() &&
        lhs.updateRecommended.sorted() == rhs.updateRecommended.sorted()
    }
    
    func insert(required: String) {
        updateRequired.append(required)
    }
    
    func insert(recommended: String) {
        updateRecommended.append(recommended)
    }
}
