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

import UIKit
import Photos
import ProtonCoreUIFoundations

/// Custom activity for `UIActivityViewController`
/// Because `UIActivityViewController` can't save `PHLivePhoto` (It throws error)
/// Have to use `PHPhotoLibrary` to assemble image and video data manually
final class SaveLivePhotoActivity: UIActivity {
    override var activityType: UIActivity.ActivityType? { .saveLivePhoto }
    override var activityTitle: String? { "Save Live Photo" }
    override var activityImage: UIImage? { IconProvider.arrowDownToSquare }
    
    let imageURL: URL
    let videoURL: URL
    
    init(imageURL: URL, videoURL: URL) {
        self.imageURL = imageURL
        self.videoURL = videoURL
    }
    
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        true
    }
    
    override func perform() {
        PHPhotoLibrary.shared().performChanges({
            let creationRequest = PHAssetCreationRequest.forAsset()
            let options = PHAssetResourceCreationOptions()
            creationRequest.addResource(with: PHAssetResourceType.photo, fileURL: self.imageURL, options: options)
            creationRequest.addResource(with: PHAssetResourceType.pairedVideo, fileURL: self.videoURL, options: options)
        }, completionHandler: { success, _ in
            self.activityDidFinish(true)
        })
    }
}

extension UIActivity.ActivityType {
    static let saveLivePhoto = UIActivity.ActivityType("ch.protonmail.drive.save.live.photo.activity")
}
