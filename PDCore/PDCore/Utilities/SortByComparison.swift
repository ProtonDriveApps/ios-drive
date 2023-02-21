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

extension Sequence {
    typealias ComparisonPredicate = (Element, Element) -> Bool

    func sorted(by first: ComparisonPredicate,
                _ second: ComparisonPredicate,
                _ others: ComparisonPredicate...) -> [Element] {
        return sorted(by:) { lhs, rhs in
            if first(lhs, rhs) { return true }
            if first(rhs, lhs) { return false }
            if second(lhs, rhs) { return true }
            if second(rhs, lhs) { return false }
            for predicate in others {
                if predicate(lhs, rhs) { return true }
                if predicate(rhs, lhs) { return false }
            }
            return false
        }
    }
}
