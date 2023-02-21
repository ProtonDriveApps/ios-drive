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

extension Int {
    func split(divisor: Int) -> [Int] {
        assert(self >= .zero, "Divident must be greater than or equal to zero")
        assert(divisor > .zero, "Divisor must be greater than zero")

        let residue = self % divisor
        let quotient = self / divisor
        var components = Array(repeating: divisor, count: quotient)

        if residue > .zero {
            components.append(residue)
        }

        return components
    }
}
