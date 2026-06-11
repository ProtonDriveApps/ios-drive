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

import Photos
import PhotosUI
import UIKit
import ProtonCoreUIFoundations
import PDLocalization

enum PreviewDataType: Equatable {
    case thumbnail(Data)
    case image(Data)
    case gif(Data)
    /// PhotoURL, VideoURL, isLoading
    case livePhoto(URL, URL?, Bool)
    /// PhotoURL, childrenURL, isLoading
    case burstPhoto(URL, [URL], Bool)
}

final class InteractiveImageView: UIView, UIScrollViewDelegate {
    private let scrollView = UIScrollView()
    private var photoView: UIView?
    private var lastBounds = CGRect.zero
    private var isLoadingViewShown = false
    private let loadingView: UIView
    private var loadingVerticalConstraint: NSLayoutConstraint?
    private var loadingHorizontalConstraint: NSLayoutConstraint?
    private weak var parentViewController: UIViewController?

    var isAfterLivePhotoPlayed: Bool {
        guard let view = photoView as? LivePhotoPreviewView else { return false }
        return view.isAfterLivePhotoPlayed
    }
    private var displayMode: PhotosPreviewMode {
        didSet { updateBadgeHiddenStatus() }
    }
    private var zoomScale: CGFloat = 1 {
        didSet { updateBadgeHiddenStatus() }
    }
    private let factory: InteractivePhotoViewFactory

    init(
        data: PreviewDataType,
        displayMode: PhotosPreviewMode,
        factory: InteractivePhotoViewFactory = .init(),
        parentViewController: UIViewController,
        loadingView: UIView
    ) {
        self.displayMode = displayMode
        self.factory = factory
        self.parentViewController = parentViewController
        self.loadingView = loadingView
        super.init(frame: .zero)
        setupLayout(with: data)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        updateLoadingViewConstraintsIfNeeded()

        guard lastBounds != bounds else {
            return
        }

        lastBounds = bounds
        scrollView.setZoomScale(1, animated: false)
        scrollView.safeAreaInsetsDidChange()
    }

    private func updateLoadingViewConstraintsIfNeeded() {
        guard let contentSize = getZoomedContentSize() else {
            return
        }

        let verticalConstant = contentSize.height / 2
        if loadingVerticalConstraint?.constant != verticalConstant {
            loadingVerticalConstraint?.constant = verticalConstant
        }
        let horizontalConstant = -contentSize.width / 2
        if loadingHorizontalConstraint?.constant != horizontalConstant {
            loadingHorizontalConstraint?.constant = horizontalConstant
        }
    }

    func setupLayout(with data: PreviewDataType) {
        setupScrollView() // Need to readd subviews & constraints since they're removed from parent VC
        switch data {
        case .thumbnail(let data):
            let imageView = factory.makeStaticImageView(with: data)
            setUpPhotoViewLayout(photoView: imageView, in: scrollView)
            isLoadingViewShown = true
            accessibilityIdentifier = "PhotoPreviewDetail.Image.thumbnail"
        case .image(let data):
            let imageView = factory.makeStaticImageView(with: data)
            setUpPhotoViewLayout(photoView: imageView, in: scrollView)
            isLoadingViewShown = true
            accessibilityIdentifier = "PhotoPreviewDetail.Image"
        case .gif(let data):
            let gifView = factory.makeGIFView(with: data)
            setUpPhotoViewLayout(photoView: gifView, in: scrollView)
            isLoadingViewShown = false
            accessibilityIdentifier = "PhotoPreviewDetail.gif"
        case let .livePhoto(photoURL, videoURL, isLoading):
            let livePhotoView = factory.makeLivePhotoPreview(photoURL: photoURL, videoURL: videoURL, isLoading: isLoading)
            setUpPhotoViewLayout(photoView: livePhotoView, in: scrollView)
            updateBadgeHiddenStatus()
            isLoadingViewShown = false
            accessibilityIdentifier = isLoading ? "PhotoPreviewDetail.LivePhoto.loading" : "PhotoPreviewDetail.LivePhoto"
        case let .burstPhoto(coverURL, childrenURLs, isLoading):
            let burstView = factory.makeBurstPhotoPreview(
                coverURL: coverURL,
                childrenURLs: childrenURLs,
                isLoading: isLoading,
                parentViewController: parentViewController
            )
            setUpPhotoViewLayout(photoView: burstView, in: scrollView)
            updateBadgeHiddenStatus()
            isLoadingViewShown = false
            accessibilityIdentifier = isLoading ? "PhotoPreviewDetail.Burst.loading" : "PhotoPreviewDetail.Burst"
        }
        updateLoadingBadge()
    }

    func handleDoubleTap() {
        if scrollView.zoomScale == 1 {
            scrollView.setZoomScale(2, animated: true)
        } else {
            scrollView.setZoomScale(1, animated: true)
        }
    }
    
    func updateCurrentDisplayMode(mode: PhotosPreviewMode) {
        displayMode = mode
    }

    // MARK: - UIScrollViewDelegate

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return photoView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        updateZoom()
        updateLoadingBadge()
    }
    
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        zoomScale = scale
    }

    private func getContentSize() -> CGSize? {
        guard let photoView else {
            return nil
        }
        if let photoView = photoView as? UIImageView, let photo = photoView.image {
            return photo.size
        } else if let photoView = photoView as? LivePhotoPreviewView {
            return photoView.livePhoto?.size
        } else {
            return nil
        }
    }

    private func getZoomedContentSize() -> CGSize? {
        guard let size = getContentSize() else {
            return nil
        }
        let widthRatio = scrollView.frame.width / size.width
        let heightRatio = scrollView.frame.height / size.height
        let ratio = widthRatio < heightRatio ? widthRatio : heightRatio
        let newWidth = size.width * ratio
        let newHeight = size.height * ratio
        return CGSize(width: newWidth, height: newHeight)
    }

    private func updateZoom() {
        guard let photoView else {
            return
        }
        guard let size = getContentSize() else {
            return
        }
        guard scrollView.zoomScale > 1 else {
            scrollView.contentInset = .zero
            return
        }

        // When image is zoomed so it covers whole screen we want to limit panning.
        let widthRatio = photoView.frame.width / size.width
        let heightRatio = photoView.frame.height / size.height
        let ratio = widthRatio < heightRatio ? widthRatio : heightRatio
        let newWidth = size.width * ratio
        let newHeight = size.height * ratio
        let isWidthOutOfBounds = newWidth * scrollView.zoomScale > photoView.frame.width
        let left = 0.5 * (isWidthOutOfBounds ? newWidth - photoView.frame.width : (scrollView.frame.width - scrollView.contentSize.width))
        let isHeightOutOfBounds = newHeight * scrollView.zoomScale > photoView.frame.height
        let top = 0.5 * (isHeightOutOfBounds ? newHeight - photoView.frame.height : (scrollView.frame.height - scrollView.contentSize.height))
        scrollView.contentInset = UIEdgeInsets(top: top, left: left, bottom: top, right: left)
    }
}

// MARK: - View setup
extension InteractiveImageView {
    private func setupScrollView() {
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 3
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.automaticallyAdjustsScrollIndicatorInsets = false
        scrollView.delegate = self
        addSubview(scrollView)
        scrollView.fillSuperview()
        addSubview(loadingView)
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        setupLoadingViewLayout()
    }

    private func setupLoadingViewLayout() {
        loadingView.setSizeContraint(height: 40, width: 40)
        loadingHorizontalConstraint = loadingView.leadingAnchor.constraint(equalTo: scrollView.centerXAnchor)
        loadingHorizontalConstraint?.priority = .defaultHigh
        loadingHorizontalConstraint?.isActive = true
        loadingVerticalConstraint = loadingView.bottomAnchor.constraint(equalTo: scrollView.centerYAnchor)
        loadingVerticalConstraint?.priority = .defaultHigh
        loadingVerticalConstraint?.isActive = true
        loadingView.leadingAnchor.constraint(greaterThanOrEqualTo: scrollView.safeAreaLayoutGuide.leadingAnchor).isActive = true
        loadingView.bottomAnchor.constraint(lessThanOrEqualTo: scrollView.safeAreaLayoutGuide.bottomAnchor).isActive = true
    }

    private func setUpPhotoViewLayout(photoView: UIView, in scrollView: UIScrollView) {
        photoView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(photoView)
        NSLayoutConstraint.activate([
            photoView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            photoView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
            photoView.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            photoView.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
        ])
        if self.photoView != nil {
            self.photoView?.removeFromSuperview()
        }
        self.photoView = photoView
        scrollView.bringSubviewToFront(loadingView)
    }

    private func updateBadgeHiddenStatus() {
        guard let badgeSupportView = photoView as? PreviewBadgeSupport else { return }
        if displayMode == .focus {
            badgeSupportView.updateLivePhotoBadgeHiddenStatus(isHidden: true)
        } else {
            let isMinimize = zoomScale == scrollView.minimumZoomScale
            badgeSupportView.updateLivePhotoBadgeHiddenStatus(isHidden: !isMinimize)
        }
    }

    private func updateLoadingBadge() {
        // Show loading view only when zoomed out and when displaying still image
        loadingView.isHidden = !isLoadingViewShown || scrollView.zoomScale != 1
    }
}
