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
import ImageIO

final class IncrementalImagePropertyAccumulator {
    typealias PropertyExtractor = (_ accumulatedData: Data, _ isFinal: Bool) -> NSDictionary?

    // Thread safe
    private let queue: DispatchQueue = DispatchQueue(label: "ch.protonmail.drive.photos.exif-accumulator")
    private var accumulatedData = Data()
    private var properties: NSDictionary?
    private var extractor: PropertyExtractor?

    init(extractor: @escaping PropertyExtractor) {
        self.extractor = extractor
    }

    /// Default factory backed by `CGImageSourceCreateIncremental`.
    /// The underlying `CGImageSource` is captured by the extractor and released once
    /// `properties` are resolved or `finalize()` runs.
    static func imageIO() -> IncrementalImagePropertyAccumulator {
        let imageSource = CGImageSourceCreateIncremental(nil)
        return IncrementalImagePropertyAccumulator { accumulatedData, isFinal in
            CGImageSourceUpdateData(imageSource, accumulatedData as CFData, isFinal)
            return CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as NSDictionary?
        }
    }

    func append(_ chunk: Data) {
        queue.sync {
            guard let extractor, properties == nil else { return }

            accumulatedData.append(chunk)
            if let candidate = extractor(accumulatedData, false), isResolved(candidate) {
                // Properties can be parsed before the full data is received
                resolve(with: candidate)
            }
        }
    }

    func finalize() -> NSDictionary? {
        queue.sync {
            guard let extractor, properties == nil else { return properties }

            if let candidate = extractor(accumulatedData, true) {
                // When finalize, we return what we have
                resolve(with: candidate)
            } else {
                releaseBuffers()
            }
            return properties
        }
    }

    private func resolve(with candidate: NSDictionary) {
        properties = candidate
        releaseBuffers()
    }

    /// Releases the byte buffer and drops the extractor closure so any resources it
    /// captured (e.g. `CGImageSource`) are freed as soon as we have a result.
    private func releaseBuffers() {
        accumulatedData.removeAll(keepingCapacity: false)
        extractor = nil
    }

    private func isResolved(_ dict: NSDictionary) -> Bool {
        // Some formats don't contain TIFF metadata, this logic may increase memory usage,
        // but this is the most reliable way to parse image properties
        dict[kCGImagePropertyExifDictionary] != nil && dict[kCGImagePropertyTIFFDictionary] != nil
    }
}
