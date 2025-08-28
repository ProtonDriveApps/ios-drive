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
import ImageIO

public final class ImageInspector {
    private let imageSource: CGImageSource

    /// Creates an inspector for the image at the given URL.
    /// Fails if the image source cannot be created.
    public init?(url: URL) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        self.imageSource = source
    }

    // MARK: - Lazy-Loaded Property Dictionaries

    /// The main properties dictionary for the image. Loaded only when first accessed.
    public private(set) lazy var properties: [String: Any]? = {
        return CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any]
    }()

    /// The EXIF sub-dictionary. Loaded only when first accessed.
    public private(set) lazy var exifDict: [String: Any]? = {
        guard let properties = self.properties else { return nil }
        return properties[kCGImagePropertyExifDictionary as String] as? [String: Any]
    }()

    // MARK: - Specific Metadata Properties
    public var userComment: String? {
        exifDict?[kCGImagePropertyExifUserComment as String] as? String
    }

    public var lensModel: String? {
        exifDict?[kCGImagePropertyExifLensModel as String] as? String
    }

    public var customRendered: Int? {
        exifDict?[kCGImagePropertyExifCustomRendered as String] as? Int
    }

    public var pixelWidth: CGFloat? {
        properties?[kCGImagePropertyPixelWidth as String] as? CGFloat
    }

    public var pixelHeight: CGFloat? {
        properties?[kCGImagePropertyPixelHeight as String] as? CGFloat
    }

    public var aspectRatio: CGFloat? {
        guard let width = pixelWidth, let height = pixelHeight, height > 0 else {
            return nil
        }
        return width / height
    }

    // MARK: - XMP Path Helper

    /// A helper to read a string value from a specific XMP path.
    /// Note: This only works for XMP *elements*, not attributes.
    public func xmpStringValue(for path: String) -> String? {
        guard let metadata = CGImageSourceCopyMetadataAtIndex(imageSource, 0, nil) else {
            return nil
        }
        return CGImageMetadataCopyStringValueWithPath(metadata, nil, path as CFString) as? String
    }
}
