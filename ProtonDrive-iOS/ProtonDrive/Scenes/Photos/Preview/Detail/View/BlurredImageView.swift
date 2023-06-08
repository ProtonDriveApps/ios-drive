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

final class BlurredImageView: UIView {
    init(data: Data) {
        super.init(frame: .zero)
        setupLayout(with: data)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout(with data: Data) {
        guard let image = UIImage(data: data), image.size != .zero else {
            return
        }

        let ratio = image.size.width / image.size.height
        let containerView = UIView()
        let imageView = UIImageView(image: UIImage(data: data))
        imageView.contentMode = .scaleAspectFit
        imageView.setContentHuggingPriority(.required, for: .vertical)
        let blurEffect = UIBlurEffect(style: .light)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(containerView)
        containerView.addSubview(imageView)
        containerView.addSubview(blurEffectView)
        containerView.centerInSuperview()
        imageView.fillSuperview()
        blurEffectView.fillSuperview()
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(greaterThanOrEqualTo: topAnchor),
            containerView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),
            containerView.leftAnchor.constraint(greaterThanOrEqualTo: leftAnchor),
            containerView.rightAnchor.constraint(lessThanOrEqualTo: rightAnchor),
            imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor, multiplier: ratio)
        ])
    }
}
