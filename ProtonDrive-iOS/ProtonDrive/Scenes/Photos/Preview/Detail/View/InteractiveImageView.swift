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

import UIKit

final class InteractiveImageView: UIView, UIScrollViewDelegate {
    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private var lastBounds = CGRect.zero

    init(data: Data) {
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

    private func setupLayout(with data: Data) {
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 3
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.automaticallyAdjustsScrollIndicatorInsets = false
        scrollView.delegate = self
        addImageView(with: data)
    }

    private func addImageView(with data: Data) {
        addSubview(scrollView)
        scrollView.fillSuperview()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(data: data)
        scrollView.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
            imageView.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
        ])
    }

    func handleDoubleTap() {
        if scrollView.zoomScale == 1 {
            scrollView.setZoomScale(2, animated: true)
        } else {
            scrollView.setZoomScale(1, animated: true)
        }
    }

    // MARK: - UIScrollViewDelegate

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        updateZoom()
    }

    private func updateZoom() {
        guard let image = imageView.image else {
            return
        }

        guard scrollView.zoomScale > 1 else {
            scrollView.contentInset = .zero
            return
        }

        // When image is zoomed so it covers whole screen we want to limit panning.
        let widthRatio = imageView.frame.width / image.size.width
        let heightRatio = imageView.frame.height / image.size.height
        let ratio = widthRatio < heightRatio ? widthRatio : heightRatio
        let newWidth = image.size.width * ratio
        let newHeight = image.size.height * ratio
        let isWidthOutOfBounds = newWidth * scrollView.zoomScale > imageView.frame.width
        let left = 0.5 * (isWidthOutOfBounds ? newWidth - imageView.frame.width : (scrollView.frame.width - scrollView.contentSize.width))
        let isHeightOutOfBounds = newHeight * scrollView.zoomScale > imageView.frame.height
        let top = 0.5 * (isHeightOutOfBounds ? newHeight - imageView.frame.height : (scrollView.frame.height - scrollView.contentSize.height))
        scrollView.contentInset = UIEdgeInsets(top: top, left: left, bottom: top, right: left)
    }
}
