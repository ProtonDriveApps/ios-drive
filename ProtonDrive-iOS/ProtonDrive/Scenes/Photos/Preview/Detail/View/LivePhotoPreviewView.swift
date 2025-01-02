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
import Foundation
import Photos
import PhotosUI
import UIKit

protocol PreviewBadgeSupport {
    func updateLivePhotoBadgeHiddenStatus(isHidden: Bool)
}

final class LivePhotoPreviewView: UIView, PreviewBadgeSupport {
    private let isLoading: Bool
    private let photoURL: URL
    private let videoURL: URL?
    private var debounceTimer: Timer?
    private var isBadgeHidden = true
    private var livePhotoView: PHLivePhotoView?
    private var photoBadgeView: PhotoBadgeView?
    private var placeholderView: UIImageView?
    private(set) var isAfterLivePhotoPlayed: Bool = false
    
    init(photoURL: URL, videoURL: URL?, isLoading: Bool) {
        self.photoURL = photoURL
        self.videoURL = isLoading ? nil : videoURL
        self.isLoading = isLoading
        super.init(frame: .zero)
        Task {
            await loadLivePhoto()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateLivePhotoBadgeHiddenStatus(isHidden: Bool) {
        isBadgeHidden = isHidden
        photoBadgeView?.isHidden = isHidden
    }
}

extension LivePhotoPreviewView {
    private func loadLivePhoto() async {
        var resources: [URL] = [photoURL]
        
        guard let data = try? Data(contentsOf: photoURL) else { return }
        var placeholder: UIImage? = UIImage(data: data)
        if let videoURL {
            resources.append(videoURL)
            for await livePhoto in PHLivePhoto.load(resources: resources, placeholderImage: placeholder) {
                guard let livePhoto else { continue }
                setupLivePhotoView(with: livePhoto, isLoading: isLoading)
            }
        } else {
            await setupPlaceholder(data: data)
        }
    }
    
    @MainActor
    private func setupLivePhotoView(with livePhoto: PHLivePhoto, isLoading: Bool) {
        let livePhotoView = PHLivePhotoView()
        livePhotoView.livePhoto = livePhoto
        livePhotoView.delegate = self
        
        if let photoArea = livePhotoView.subviews.first?.subviews.first {
            setUpBadgeOfLivePhoto(to: photoArea, isLoading: isLoading)
        }
        if let placeholderView {
            placeholderView.removeFromSuperview()
            self.placeholderView = nil
        }
        addSubviews(livePhotoView)
        livePhotoView.fillSuperview()
        self.livePhotoView = livePhotoView
        livePhotoView.contentMode = .scaleAspectFit
    }
    
    private func setUpBadgeOfLivePhoto(to photoArea: UIView, isLoading: Bool) {
        if let photoBadgeView {
            photoBadgeView.removeFromSuperview()
        }
        let badge = PhotoBadgeView(type: .livePhoto(isLoading))
        photoBadgeView = badge
        badge.translatesAutoresizingMaskIntoConstraints = false
        photoArea.addSubview(badge)
        NSLayoutConstraint.activate([
            badge.leadingAnchor.constraint(equalTo: photoArea.leadingAnchor, constant: 8),
            badge.topAnchor.constraint(equalTo: photoArea.topAnchor, constant: 8)
        ])
        updateLivePhotoBadgeHiddenStatus(isHidden: isBadgeHidden)
    }
    
    @MainActor
    private func setupPlaceholder(data: Data) async {
        let imageView = UIImageView(image: UIImage(data: data))
        addSubview(imageView)
        imageView.fillSuperview()
        imageView.contentMode = .scaleAspectFit
        placeholderView = imageView
        await MainActor.run {
            // To make sure frame of placeholderView is correct
            setupLoadingBadge()
        }
    }

    private func setupLoadingBadge() {
        guard 
            let placeholderView,
            let imageSize = placeholderView.image?.size,
            let screenSize = self.window?.screen.bounds
        else { return }
        
        if screenSize.width < placeholderView.bounds.width && screenSize.height < placeholderView.bounds.height {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.setupLoadingBadge()
            }
            return
        }
        
        let rect = AVMakeRect(aspectRatio: imageSize, insideRect: placeholderView.bounds)
        
        if let photoBadgeView {
            photoBadgeView.removeFromSuperview()
        }
        let badge = PhotoBadgeView(type: .livePhoto(true))
        photoBadgeView = badge
        badge.translatesAutoresizingMaskIntoConstraints = false
        addSubview(badge)
        NSLayoutConstraint.activate([
            badge.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            badge.topAnchor.constraint(equalTo: topAnchor, constant: rect.minY + 8)
        ])
    }
}

extension LivePhotoPreviewView: PHLivePhotoViewDelegate {
    func livePhotoView(_ livePhotoView: PHLivePhotoView, willBeginPlaybackWith playbackStyle: PHLivePhotoViewPlaybackStyle) {
        photoBadgeView?.isHidden = true
    }
    
    func livePhotoView(_ livePhotoView: PHLivePhotoView, didEndPlaybackWith playbackStyle: PHLivePhotoViewPlaybackStyle) {
        updateLivePhotoBadgeHiddenStatus(isHidden: isBadgeHidden)
        
        isAfterLivePhotoPlayed = true
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false, block: { [weak self] _ in
            self?.debounceTimer?.invalidate()
            self?.debounceTimer = nil
            self?.isAfterLivePhotoPlayed = false
        })
    }
}
