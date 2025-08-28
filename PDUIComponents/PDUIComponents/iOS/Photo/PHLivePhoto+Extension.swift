// Copyright (c) 2024 Proton AG
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

#if os(iOS)
import Foundation
import Photos
import UIKit

public extension PHLivePhoto {
    static func load(resources: [URL]) async -> PHLivePhoto? {
        return await withCheckedContinuation { continuation in
            PHLivePhoto.request(
                withResourceFileURLs: resources,
                placeholderImage: nil,
                targetSize: .zero,
                contentMode: .default
            ) { livePhoto, info in
                // Handler will be called twice
                // The first time is to provide low quality image
                if let isLowQuality = info["PHLivePhotoInfoIsDegradedKey"] as? Int, isLowQuality == 1 {
                    return
                }
                continuation.resume(returning: livePhoto)
            }
        }
    }
    
    static func load(resources: [URL], placeholderImage: UIImage? = nil) -> AsyncStream<PHLivePhoto?> {
        AsyncStream { continuation in
            PHLivePhoto.request(
                withResourceFileURLs: resources,
                placeholderImage: placeholderImage,
                targetSize: .zero,
                contentMode: .default
            ) { livePhoto, info in
                if let isLowQuality = info["PHLivePhotoInfoIsDegradedKey"] as? Int, isLowQuality == 1 {
                    continuation.yield(livePhoto)
                } else {
                    continuation.yield(livePhoto)
                    continuation.finish()
                }
            }
        }
    }
}
#endif
