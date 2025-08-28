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
import UIKit

extension String {
    func asAttributedString(keywords: [String], highlightColor: UIColor) -> NSMutableAttributedString {
        let stringToHighlight = NSMutableAttributedString(string: self)
        let ranges = nonIntersectingRanges(of: keywords, in: self)

        for range in ranges {
            let nsRange = NSRange(range, in: self.lowercased())
            stringToHighlight.addAttribute(.foregroundColor, value: highlightColor, range: nsRange)
        }

        return stringToHighlight
    }

    /// Ranges returned by this method are guaranteed not to overlap.
    /// Overlapping ranges are not filtered out, but merged, so all keywords are still fully covered.
    private func nonIntersectingRanges(of keywords: [String], in text: String) -> [Range<String.Index>] {
        let text = text.lowercased()
        let keywords = keywords.map { $0.lowercased() }
        var ranges = [Range<String.Index>]()

        for keyword in keywords {
            var startingPosition = text.startIndex

            while let nextRange = text.range(
                of: keyword,
                range: startingPosition..<text.endIndex
            ) {
                ranges.append(nextRange)
                startingPosition = nextRange.upperBound
            }
        }

        // Make sure there are no overlaps when highlighting - if necessary merge the highlighted parts
        return ranges.nonIntersecting()
    }
}

private extension Array where Element == Range<String.Index> {
    func nonIntersecting() -> Self {
        let sortedOccurrences = sorted { $0.lowerBound < $1.lowerBound }

        return sortedOccurrences.reduce(into: []) { resolvedNonIntersectingRanges, nextOccurrence in
            guard !resolvedNonIntersectingRanges.isEmpty else {
                resolvedNonIntersectingRanges.append(nextOccurrence)
                return
            }

            let rightmostResolvedRangeIndex = resolvedNonIntersectingRanges.endIndex - 1
            let rightmostResolvedRange = resolvedNonIntersectingRanges[rightmostResolvedRangeIndex]

            if rightmostResolvedRange.overlaps(nextOccurrence) {
                let upperBoundFarthestToTheRight = Swift.max(
                    rightmostResolvedRange.upperBound,
                    nextOccurrence.upperBound
                )

                resolvedNonIntersectingRanges[rightmostResolvedRangeIndex] = (
                    rightmostResolvedRange.lowerBound ..< upperBoundFarthestToTheRight
                )
            } else {
                resolvedNonIntersectingRanges.append(nextOccurrence)
            }
        }
    }
}
