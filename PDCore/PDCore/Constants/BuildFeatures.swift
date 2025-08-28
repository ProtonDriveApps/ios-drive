// Copyright (c) 2025 Proton AG
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

public struct BuildFeatures {
    public let hasPayments: Bool
    public let hasUnlimitedPicker: Bool
    public let hasSignUp: Bool

    public init(hasPayments: Bool, hasUnlimitedPicker: Bool, hasSignUp: Bool) {
        self.hasPayments = hasPayments
        self.hasUnlimitedPicker = hasUnlimitedPicker
        self.hasSignUp = hasSignUp
    }

    static var `default`: BuildFeatures {
        // Gives highest build type constraints (should equal to prod. build constants)
        BuildFeatures(hasPayments: true, hasUnlimitedPicker: false, hasSignUp: true)
    }
}
