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
    private var badgeTopConstraint: NSLayoutConstraint?
    private weak var parentViewController: UIViewController?
    private var lastLaidOutBounds: CGRect?
    
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
    
    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0 else { return }
        guard bounds != lastLaidOutBounds else { return } // avoid repeated rebuild
        lastLaidOutBounds = bounds
        // Update badge layout after `coverImageView` get the correct bounds
        setupBadgeLayout()
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
    }
    
    func setupBadgeLayout() {
        guard
            let coverImageView,
            let imageSize = coverImageView.image?.size
        else { return }
        let rect = AVMakeRect(aspectRatio: imageSize, insideRect: coverImageView.bounds)

        let badge: PhotoBadgeView
        if let existingBadge = photoBadgeView {
            badge = existingBadge
        } else {
            let newBadge = PhotoBadgeView(type: .burst(isLoading))
            newBadge.translatesAutoresizingMaskIntoConstraints = false
            addSubview(newBadge)
            NSLayoutConstraint.activate([
                newBadge.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8)
            ])
            badgeTopConstraint = newBadge.topAnchor.constraint(equalTo: topAnchor, constant: rect.minY + 8)
            badgeTopConstraint?.isActive = true
            photoBadgeView = newBadge
            let suffix = isLoading ? "loading" : "loaded"
            newBadge.accessibilityIdentifier = "PhotoPreviewDetail.Burst.badge.\(suffix)"
            setupBadgeTapGesture()
            badge = newBadge
        }

        badgeTopConstraint?.constant = rect.minY + 8
        badge.isHidden = isBadgeHidden
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
