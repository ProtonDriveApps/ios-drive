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

import CoreServices
import CoreImage

final class CGImageThumbnailProvider: ThumbnailProvider {

    var next: ThumbnailProvider?
    
    init(next: ThumbnailProvider? = nil) {
        self.next = next
    }

    func getThumbnail(from url: URL, ofSize size: CGSize) -> Image? {
        guard MimeType(fromFileExtension: url.pathExtension)?.isImage == true else {
            return next?.getThumbnail(from: url, ofSize: size)
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: size.height
        ]

        guard let imageSource = CGImageSourceCreateWithURL(url as NSURL, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            return nil
        }

        return cgImage
    }
}
