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

import AVFoundation
import PDUIComponents
import SwiftUI
import UIKit

final class BurstPhotoPreviewView: UIView, PreviewBadgeSupport {
    private let childrenURLs: [URL]
    private let coverURL: URL
    private let isLoading: Bool
    private var coverImageView: UIImageView?
    private var isBadgeHidden = true
    private var photoBadgeView: PhotoBadgeView?
    private weak var parentViewController: UIViewController?
    
    init(isLoading: Bool, coverURL: URL, childrenURLs: [URL], parentViewController: UIViewController?) {
        self.isLoading = isLoading
        self.coverURL = coverURL
        self.childrenURLs = childrenURLs
        self.parentViewController = parentViewController
        super.init(frame: .zero)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateLivePhotoBadgeHiddenStatus(isHidden: Bool) {
        isBadgeHidden = isHidden
        photoBadgeView?.isHidden = isHidden
    }
}

extension BurstPhotoPreviewView {
    private func setupViews() {
        setupCoverPhoto()
    }
    
    private func setupCoverPhoto() {
        guard let data = try? Data(contentsOf: coverURL) else { return }
        let imageView = UIImageView(image: .init(data: data))
        addSubview(imageView)
        imageView.fillSuperview()
        imageView.contentMode = .scaleAspectFit
        coverImageView = imageView
        DispatchQueue.main.async {
            self.setupBadge()
        }
    }
    
    private func setupBadge() {
        guard
            let coverImageView,
            let imageSize = coverImageView.image?.size
        else { return }
        let rect = AVMakeRect(aspectRatio: imageSize, insideRect: coverImageView.bounds)
        
        if let photoBadgeView {
            photoBadgeView.removeFromSuperview()
        }
        let badge = PhotoBadgeView(type: .burst(isLoading))
        photoBadgeView = badge
        badge.translatesAutoresizingMaskIntoConstraints = false
        addSubview(badge)
        NSLayoutConstraint.activate([
            badge.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            badge.topAnchor.constraint(equalTo: topAnchor, constant: rect.minY + 8)
        ])
        let suffix = isLoading ? "loading" : "loaded"
        badge.accessibilityIdentifier = "PhotoPreviewDetail.Burst.badge.\(suffix)"
        setupBadgeTapGesture()
    }
    
    private func setupBadgeTapGesture() {
        guard let photoBadgeView else { return }
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapBadge))
        photoBadgeView.addGestureRecognizer(tap)
    }
    
    @objc
    private func tapBadge() {
        let galleryView = BurstGalleryView(
            viewModel: .init(coverURL: coverURL, childrenURLs: childrenURLs)
        ).embeddedInHostingController()
        let nav = UINavigationController(rootViewController: galleryView)
        nav.isModalInPresentation = true
        parentViewController?.present(nav, animated: true)
    }
}
