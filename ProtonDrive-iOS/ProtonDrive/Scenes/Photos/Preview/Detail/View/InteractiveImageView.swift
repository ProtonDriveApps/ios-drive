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

enum PreviewDataType {
    case image(Data)
    case gif(Data)
    /// PhotoURL, VideoURL
    case livePhoto(URL, URL)
}

final class InteractiveImageView: UIView, UIScrollViewDelegate {
    private let scrollView = UIScrollView()
    private var photoView: UIView?
    private var lastBounds = CGRect.zero

    private var livePhotoBadgeView: UIView?
    private var displayMode: PhotosPreviewMode {
        didSet { updateLivePhotoBadgeHiddenStatus() }
    }
    private var zoomScale: CGFloat = 1 {
        didSet { updateLivePhotoBadgeHiddenStatus() }
    }

    private(set) var isAfterLivePhotoPlayed: Bool = false
    private var debounceTimer: Timer?

    init(data: PreviewDataType, displayMode: PhotosPreviewMode) {
        self.displayMode = displayMode
        super.init(frame: .zero)
        setupLayout(with: data)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard lastBounds != bounds else {
            return
        }

        lastBounds = bounds
        scrollView.setZoomScale(1, animated: false)
        scrollView.safeAreaInsetsDidChange()
    }

    private func setupLayout(with data: PreviewDataType) {
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 3
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.automaticallyAdjustsScrollIndicatorInsets = false
        scrollView.delegate = self
        switch data {
        case .image(let data):
            setUpLayoutOfImageView(from: data)
        case .gif(let data):
            setUpLayoutOfImageView(from: data, isGif: true)
        case let .livePhoto(photoURL, videoURL):
            Task {
                await handleLivePhotoData(photoURL: photoURL, videoURL: videoURL)
            }
        }
    }

    private func setUpPhotoViewLayout(photoView: UIView, in scrollView: UIScrollView) {
        photoView.translatesAutoresizingMaskIntoConstraints = false
        photoView.contentMode = .scaleAspectFit
        scrollView.addSubview(photoView)
        NSLayoutConstraint.activate([
            photoView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            photoView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
            photoView.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            photoView.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
        ])
        self.photoView = photoView
        setAccessibilityIdentifier()
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
    }
    
    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        zoomScale = scale
    }

    private func updateZoom() {
        guard let photoView else { return }
        let size: CGSize
        if let photoView = photoView as? UIImageView, let photo = photoView.image {
            size = photo.size
        } else if let photoView = photoView as? PHLivePhotoView, let livePhoto = photoView.livePhoto {
            size = livePhoto.size
        } else {
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
    
    private func setAccessibilityIdentifier() {
        if photoView is UIImageView {
            accessibilityIdentifier = "PhotoPreviewDetail.Image"
        } else if photoView is PHLivePhotoView {
            accessibilityIdentifier = "PhotoPreviewDetail.LivePhoto"
        }
    }
}

// MARK: - Image
extension InteractiveImageView {
    private func setUpLayoutOfImageView(from data: Data, isGif: Bool = false) {
        let view = addImageView(with: data, isGif: isGif)
        setUpPhotoViewLayout(photoView: view, in: scrollView)
        photoView = view
    }
    
    private func addImageView(with data: Data, isGif: Bool = false) -> UIView {
        addSubview(scrollView)
        scrollView.fillSuperview()
        let imageView = UIImageView()
        if isGif {
            let cfData = data as CFData
            CGAnimateImageDataWithBlock(cfData, nil) { [weak imageView, weak self] _, cgImage, stop in
                guard self != nil else {
                    stop.pointee = true
                    return
                }
                imageView?.image = UIImage(cgImage: cgImage)
            }
        } else {
            imageView.image = UIImage(data: data)
        }
        return imageView
    }
}

// MARK: - Live photo
extension InteractiveImageView {
    private func handleLivePhotoData(photoURL: URL, videoURL: URL) async {
        guard let livePhoto = await PHLivePhoto.load(resources: [photoURL, videoURL]) else {
            let data = (try? Data(contentsOf: photoURL)) ?? Data()
            await MainActor.run {
                setUpLayoutOfImageView(from: data)
            }
            return
        }
        await MainActor.run {
            setUpLayoutOfLivePhoto(from: livePhoto)
        }
    }
    
    private func setUpLayoutOfLivePhoto(from livePhoto: PHLivePhoto) {
        let view = addLivePhotoView(with: livePhoto)
        setUpPhotoViewLayout(photoView: view, in: scrollView)
        photoView = view
    }
    
    private func addLivePhotoView(with photo: PHLivePhoto) -> UIView {
        addSubview(scrollView)
        scrollView.fillSuperview()
        let livePhotoView = PHLivePhotoView()
        livePhotoView.livePhoto = photo
        livePhotoView.delegate = self

        setUpBadgeOfLivePhoto(livePhotoView: livePhotoView)
        return livePhotoView
    }
    
    private func livePhotoBadge() -> UIView {
        let container = UIView()
        container.backgroundColor = ColorProvider.BackgroundSecondary
        
        let icon = UIImage(named: "ic-live")
        let iconView = UIImageView(image: icon)
        iconView.tintColor = ColorProvider.IconHint
        iconView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(iconView)
        
        let label = UILabel("LIVE", font: .systemFont(ofSize: 11, weight: .medium), textColor: ColorProvider.Shade80)
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 12),
            iconView.heightAnchor.constraint(equalToConstant: 12),
            iconView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 6),
            iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            iconView.topAnchor.constraint(equalTo: container.topAnchor, constant: 2),
            iconView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -2),
            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 2),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -6),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        container.roundCorner(8)
        return container
    }

    private func setUpBadgeOfLivePhoto(livePhotoView: PHLivePhotoView) {
        guard let photoArea = livePhotoView.subviews.first?.subviews.first else { return }
        let badge = livePhotoBadge()
        livePhotoBadgeView = badge
        badge.translatesAutoresizingMaskIntoConstraints = false
        livePhotoView.addSubview(badge)
        NSLayoutConstraint.activate([
            badge.leadingAnchor.constraint(equalTo: photoArea.leadingAnchor, constant: 8),
            badge.topAnchor.constraint(equalTo: photoArea.topAnchor, constant: 8)
        ])
        updateLivePhotoBadgeHiddenStatus()
    }
    
    private func updateLivePhotoBadgeHiddenStatus() {
        if displayMode == .focus {
            livePhotoBadgeView?.isHidden = true
        } else {
            let isMinimize = zoomScale == scrollView.minimumZoomScale
            livePhotoBadgeView?.isHidden = !isMinimize
        }
    }
}

extension InteractiveImageView: PHLivePhotoViewDelegate {
    func livePhotoView(_ livePhotoView: PHLivePhotoView, willBeginPlaybackWith playbackStyle: PHLivePhotoViewPlaybackStyle) {
        livePhotoBadgeView?.isHidden = true
    }
    
    func livePhotoView(_ livePhotoView: PHLivePhotoView, didEndPlaybackWith playbackStyle: PHLivePhotoViewPlaybackStyle) {
        updateLivePhotoBadgeHiddenStatus()
        
        isAfterLivePhotoPlayed = true
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false, block: { [weak self] _ in
            self?.debounceTimer?.invalidate()
            self?.debounceTimer = nil
            self?.isAfterLivePhotoPlayed = false
        })
    }
}
