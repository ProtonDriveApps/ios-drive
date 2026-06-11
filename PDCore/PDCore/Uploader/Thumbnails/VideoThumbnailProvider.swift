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

import AVFoundation

final class VideoThumbnailProvider: ThumbnailProvider {

    var next: ThumbnailProvider?

    init(next: ThumbnailProvider? = nil) {
        self.next = next
    }

    func getThumbnail(from url: URL, overrideMediaType: String?, ofSize size: CGSize) -> Image? {
        let mimeType = overrideMediaType.flatMap { MimeType(value: $0) } ?? MimeType(fromFileExtension: url.pathExtension)

        guard mimeType?.isVideo == true else {
            return next?.getThumbnail(from: url, overrideMediaType: overrideMediaType, ofSize: size)
        }

        let asset: AVURLAsset

        // Previously, this was failing on macOS due to the url not containing
        // a file extension and AVAssetImageGenerator not knowing what to do
        // with our video. Make sure to provide the override MIME type if we
        // have it.
        if #available(macOS 14, iOS 17, *) {
            asset = AVURLAsset(
                url: url,
                options: overrideMediaType.map {
                    [AVURLAssetOverrideMIMETypeKey: $0]
                }
            )
        } else {
            asset = AVURLAsset(url: url)
        }

        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = size

        return try? imageGenerator.copyCGImage(at: .zero, actualTime: nil)
    }
}
