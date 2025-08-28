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

import Foundation
import PDCore

/*
 So weight of a year should be number_of_photos_taken_that_year/total_number_of_photos
 Weight on closeness to present should be defined
 One might be
 this year and 2 before -> 1
 3-5 before -> 0.9
 6-8 before -> 0.8
 ...
 at some point we should stop on 0.1
 we multiple those 2 weights and get percentages and we distribute "dots" according to those percentages

 1st and last dot should always point to begining/end of the list / first/last item in the list
 */

struct GridScrollerYear: Equatable {
    let date: Date
    let startId: AnyVolumeIdentifier
    let items: [Item]

    struct Item: Equatable {
        /// date closest to now
        let startDate: Date
        /// date furthest from now
        let endDate: Date
        let startId: AnyVolumeIdentifier
    }
}

protocol GridScrollerItemsStrategyProtocol {
    func makeItems(months: [PhotosListSection], maximalCount: Int) -> [GridScrollerYear]
}

final class GridScrollerItemsStrategy: GridScrollerItemsStrategyProtocol {
    private let yearDateResource: YearDateResource

    init(yearDateResource: YearDateResource) {
        self.yearDateResource = yearDateResource
    }

    func makeItems(months: [PhotosListSection], maximalCount: Int) -> [GridScrollerYear] {
        guard !months.isEmpty, maximalCount > 0 else {
            // No need to make for empty data or zero size
            return []
        }

        let totalCount = months.reduce(0, { $0 + $1.photos.count })
        guard totalCount > maximalCount * 10 else {
            // No need to make for too few photos. 10 is a magic number, consider adjusting if needed
            return []
        }

        let ranges = makeWeightedRanges(from: months)

        let validRanges: [WeightedRange]
        if ranges.count > maximalCount {
            validRanges = pickValidRanges(ranges: ranges, maximalCount: maximalCount)
        } else {
            let rangesSortedByWeight = ranges.sorted(by: { $0.weight > $1.weight })
            validRanges = divideRanges(rangesSortedByWeight: rangesSortedByWeight, maximalCount: maximalCount)
        }
        let rangesSortedByDate = validRanges.sorted(by: { $0.date > $1.date })
        let years = makeYears(from: rangesSortedByDate)
        return years
    }

    /// Pick first and last range, sort the rest by weight and append the most relevant
    private func pickValidRanges(ranges: [WeightedRange], maximalCount: Int) -> [WeightedRange] {
        guard ranges.count > 2 && maximalCount > 2 else {
            return ranges
        }

        var result = [WeightedRange]()
        var ranges = ranges
        result = [ranges.removeFirst(), ranges.removeLast()]
        let rangesSortedByWeight = ranges.sorted(by: { $0.weight > $1.weight })
        result += Array(rangesSortedByWeight[0 ..< maximalCount - 2])
        return result
    }

    /// Create multiple entries for most heavy ranges to fill the list up to maximal count
    private func divideRanges(rangesSortedByWeight: [WeightedRange], maximalCount: Int) -> [WeightedRange] {
        var result = [WeightedRange]()
        var remainingCount = maximalCount - rangesSortedByWeight.count
        for range in rangesSortedByWeight {
            if remainingCount > 0 {
                let potentialCount = Int(Float(maximalCount) * range.weight)
                let numberOfSubranges = min(remainingCount + 1, potentialCount)
                let subranges = makeSubranges(from: range, count: numberOfSubranges)
                result += subranges
                remainingCount -= (numberOfSubranges - 1)
            } else {
                result.append(range)
            }
        }
        return result
    }

    private func makeSubranges(from range: WeightedRange, count: Int) -> [WeightedRange] {
        guard count > 1 else {
            return [range]
        }

        let batchCount = range.photos.count / count
        let batchOffset = range.photos.count % count
        var batches = range.photos.splitInGroups(of: batchCount)
        if batchOffset != 0, batches.count > 1 {
            let lastBatch = batches.removeLast()
            let nextToLastBatch = batches.removeLast()
            batches.append(nextToLastBatch + lastBatch)
        }

        return batches.compactMap { batch in
            let subrangeWeight = range.weight / Float(count)
            return makeWeightedRange(from: batch, weight: range.weight / subrangeWeight)
        }
    }

    private func makeYears(from ranges: [WeightedRange]) -> [GridScrollerYear] {
        var years = [GridScrollerYear]()
        var items = [GridScrollerYear.Item]()
        for range in ranges {
            guard let item = makeItem(from: range) else {
                continue
            }
            if let previousMonth = items.first, yearDateResource.isSameYear(lhs: previousMonth.startDate, rhs: range.date) {
                items.append(item)
            } else if !items.isEmpty {
                let year = GridScrollerYear(date: items[0].startDate, startId: items[0].startId, items: items)
                years.append(year)
                items = [item]
            } else {
                items = [item]
            }
        }
        if !items.isEmpty {
            let year = GridScrollerYear(date: items[0].startDate, startId: items[0].startId, items: items)
            years.append(year)
        }
        return years
    }

    private func makeItem(from range: WeightedRange) -> GridScrollerYear.Item? {
        guard let firstPhoto = range.photos.first, let lastPhoto = range.photos.last else {
            return nil
        }
        return GridScrollerYear.Item(startDate: firstPhoto.captureTime, endDate: lastPhoto.captureTime, startId: firstPhoto.id)
    }

    private func makeWeightedRanges(from months: [PhotosListSection]) -> [WeightedRange] {
        let totalCount = months.reduce(0, { $0 + $1.photos.count })
        guard let mostRecentDate = months.first?.photos.first?.captureTime else {
            return []
        }
        return months.compactMap { month in
            guard let id = month.photos.first?.id else {
                return nil
            }
            let countWeight = Float(month.photos.count) / Float(totalCount)
            let distanceWeight = makeDistanceWeight(for: month.month, mostRecentDate: mostRecentDate)
            let weight = distanceWeight * countWeight
            return WeightedRange(id: id, date: month.month, photos: month.photos, weight: weight)
        }
    }

    private func makeWeightedRange(from listings: [PhotoListing], weight: Float) -> WeightedRange? {
        guard let firstListing = listings.first else {
            return nil
        }
        return WeightedRange(id: firstListing.id, date: firstListing.captureTime, photos: listings, weight: weight)
    }

    private func makeDistanceWeight(for date: Date, mostRecentDate: Date) -> Float {
        /*
         Weight on closeness to present should be defined
         One might be
         this year and 2 before -> 1
         3-5 before -> 0.9
         6-8 before -> 0.8
         */
        let distanceFromThisYear = yearDateResource.getDistance(lhs: date, rhs: mostRecentDate)
        let distance = distanceFromThisYear / 3
        let distanceFraction = Float(distance) * 0.1
        return max(0.1, 1.0 - distanceFraction)
    }

    private struct WeightedYear {
        let date: Date
        let weightedMonths: [WeightedMonth]
    }

    private struct WeightedMonth {
        let date: Date
        let photos: [PhotoListing]
        let weight: Float
    }

    private struct WeightedRange: Hashable {
        let id: AnyVolumeIdentifier
        let date: Date
        let photos: [PhotoListing]
        let weight: Float

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    private struct Year {
        let date: Date
        let months: [PhotosListSection]
        let distanceFromThisYear: Int
        let totalCount: Int
    }
}

