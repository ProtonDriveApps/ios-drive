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

    func getThumbnail(from url: URL) -> Image? {
        guard MimeType(fromFileExtension: url.pathExtension)?.isVideo == true else { return next?.getThumbnail(from: url) }

        let asset = AVURLAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = self.maximumSize

        guard let image = try? imageGenerator.copyCGImage(at: .zero, actualTime: nil) else { return nil }
        return image
    }
}
