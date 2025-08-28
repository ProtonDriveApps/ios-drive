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

struct InteractivePhotoViewFactory {
    func makeStaticImageView(with data: Data) -> UIImageView {
        let imageView = UIImageView()
        imageView.image = UIImage(data: data)
        imageView.contentMode = .scaleAspectFit
        return imageView
    }
    
    func makeGIFView(with data: Data) -> UIImageView {
        let imageView = UIImageView()
        let cfData = data as CFData
        CGAnimateImageDataWithBlock(cfData, nil) { [weak imageView] _, cgImage, stop in
            guard let imageView else {
                stop.pointee = true
                return
            }
            imageView.image = UIImage(cgImage: cgImage)
        }
        imageView.contentMode = .scaleAspectFit
        return imageView
    }
    
    func makeLivePhotoPreview(photoURL: URL, videoURL: URL?, isLoading: Bool) -> LivePhotoPreviewView {
        let view = LivePhotoPreviewView(photoURL: photoURL, videoURL: videoURL, isLoading: isLoading)
        return view
    }
    
    func makeBurstPhotoPreview(
        coverURL: URL,
        childrenURLs: [URL],
        isLoading: Bool,
        parentViewController: UIViewController?
    ) -> BurstPhotoPreviewView {
        BurstPhotoPreviewView(
            isLoading: isLoading,
            coverURL: coverURL,
            childrenURLs: childrenURLs,
            parentViewController: parentViewController
        )
    }
}
