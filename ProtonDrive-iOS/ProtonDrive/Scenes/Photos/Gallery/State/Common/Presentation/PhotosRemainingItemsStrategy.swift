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

struct PhotosRemainingItemsCount {
    let count: Int
    let isRounded: Bool
}

protocol PhotosRemainingItemsStrategy {
    func formatRemainingCount(from count: Int) -> PhotosRemainingItemsCount
}

final class RoundingPhotosRemainingItemsStrategy: PhotosRemainingItemsStrategy {
    func formatRemainingCount(from count: Int) -> PhotosRemainingItemsCount {
        if count > 10_000 {
            return makeRoundedResult(count: count, amount: 1000)
        } else if count > 1000 {
            return makeRoundedResult(count: count, amount: 100)
        } else if count > 500 {
            return makeRoundedResult(count: count, amount: 50)
        } else if count > 100 {
            return makeRoundedResult(count: count, amount: 10)
        } else {
            return PhotosRemainingItemsCount(count: count, isRounded: false)
        }
    }

    private func makeRoundedResult(count: Int, amount: Int) -> PhotosRemainingItemsCount {
        let roundedCount = roundCount(count, by: amount)
        return PhotosRemainingItemsCount(count: roundedCount, isRounded: true)
    }

    private func roundCount(_ count: Int, by amount: Int) -> Int {
        let count = Double(count)
        let amount = Double(amount)
        return Int(floor(count / amount) * amount)
    }
}
