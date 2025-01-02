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

import Foundation
import PDLocalization
import Photos
import ProtonCoreUIFoundations
import UIKit

/// Action to save burst photo to camera roll
/// Burst photo data contains burstIdentifier that need to be updated
/// Otherwise, the downloaded image will be added to the same collection.
final class SaveBurstPhotoActivity: UIActivity {
    override var activityType: UIActivity.ActivityType? { .saveBurstPhoto }
    override var activityTitle: String? { title }
    override var activityImage: UIImage? { icon }
    private let title: String
    private let icon: UIImage
    
    let urls: [URL]
    
    /// - Parameters:
    ///   - urls: URL to retrieve the burst photos from the local file.
    ///   - saveWholeBurst: Are these URLs for the complete burst series or just a single image?
    init(urls: [URL], saveWholeBurst: Bool = true) {
        self.urls = urls
        if saveWholeBurst {
            self.title = Localization.share_action_save_burst_photo
            self.icon = IconProvider.arrowDownToSquare
        } else {
            self.title = Localization.share_action_save_image
            self.icon = IconProvider.arrowDownToSquare
        }
    }
    
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        true
    }
    
    override func perform() {
        let dataset = urls.compactMap { try? Data(contentsOf: $0) }
        let newBurstIdentifier = UUID().uuidString
        // Pattern for UUID in hex format
        let pattern = "[0-9a-f]{16}2d[0-9a-f]{8}2d[0-9a-f]{8}2d[0-9a-f]{8}2d[0-9a-f]{24}"
        
        for data in dataset {
            let hex = data.hexString()
            // The first UUID like hex in the burst photo is burstIdentifier
            // We only want to replace the identifier
            // So download images can be added to new burst collection
            // Otherwise they will be added into the same burst collection
            let changed = hex.preg_replace(pattern: pattern, with: newBurstIdentifier.toHex(), maxReplacement: 1)
            guard let newData = Data(hex: changed) else { continue }
            PHPhotoLibrary.shared().performChanges({
                let creationRequest = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                creationRequest.addResource(with: .photo, data: newData, options: options)
            }, completionHandler: { success, _ in
                self.activityDidFinish(true)
            })
        }
    }
}

extension UIActivity.ActivityType {
    static let saveBurstPhoto = UIActivity.ActivityType("ch.protonmail.drive.save.burst.photo.activity")
}
