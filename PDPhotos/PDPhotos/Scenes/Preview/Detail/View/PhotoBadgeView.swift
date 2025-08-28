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
import UIKit
import ProtonCoreUIFoundations
import PDUIComponents
import PDLocalization

enum PhotoBadge {
    /// Bool: is loading
    case livePhoto(Bool)
    /// Bool: is loading
    case burst(Bool)
}

final class PhotoBadgeView: UIView {
    private var type: PhotoBadge
    private let colorSet = ColorSet()
    private var iconView = UIImageView(frame: .zero)
    private var textLabel = UILabel(frame: .zero)
    private var nextIcon: UIImageView?
    private var stack = UIStackView()
    
    init(type: PhotoBadge) {
        self.type = type
        super.init(frame: .zero)
        setupComponents()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension PhotoBadgeView {
    private func setupComponents() {
        backgroundColor = colorSet.background
        setupStackView()
        setupIconView()
        setupTextLabel()
        setupNextIcon()
        setArrangedSubview()
        roundCorner(8)
    }
    
    private func setupIconView() {
        iconView.tintColor = colorSet.icon
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        
        switch type {
        case .livePhoto:
            iconView.image = .init(named: "ic-live")
        case .burst:
            iconView.image = .init(named: "ic-burst")
        }
        
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 12),
            iconView.heightAnchor.constraint(equalToConstant: 12)
        ])
    }
    
    private func setupTextLabel() {
        textLabel.textColor = colorSet.text
        textLabel.font = .systemFont(ofSize: 11, weight: .medium)
        setupTextLabelText()
    }
    
    private func setupTextLabelText() {
        switch type {
        case .livePhoto(let isLoading):
            let text = isLoading ? Localization.preview_loading_badge_text : Localization.preview_livePhoto_badge_text
            textLabel.text = text
        case .burst(let isLoading):
            let text = isLoading ? Localization.preview_loading_badge_text : Localization.preview_burst_badge_text
            textLabel.text = text
        }
    }
    
    private func setupNextIcon() {
        switch type {
        case .burst(let isLoading):
            if isLoading {
                nextIcon = nil
            } else {
                nextIcon = .init(image: IconProvider.chevronRight)
                nextIcon?.tintColor = colorSet.icon
            }
        default:
            nextIcon?.removeFromSuperview()
            nextIcon = nil
        }
        
        if let nextIcon {
            NSLayoutConstraint.activate([
                nextIcon.widthAnchor.constraint(equalToConstant: 12),
                nextIcon.heightAnchor.constraint(equalToConstant: 12)
            ])
        }
    }
    
    private func setupStackView() {
        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 0
        let trailing: CGFloat
        switch type {
        case .livePhoto:
            trailing = -6
        case .burst(let isLoading):
            trailing = isLoading ? -6 : -2
        }
        
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: trailing),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2)
        ])
    }
    
    private func setArrangedSubview() {
        stack.addArrangedSubview(iconView)
        stack.setCustomSpacing(4, after: iconView)
        stack.addArrangedSubview(textLabel)
        if let nextIcon {
            stack.setCustomSpacing(2, after: textLabel)
            stack.addArrangedSubview(nextIcon)
        }
    }
}

extension PhotoBadgeView {
    // There is no such color in the core library
    private struct ColorSet {
        let background = UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: "706D6B") : UIColor(hex: "F5F4F2")
        }
        let icon = UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor.white : UIColor(hex: "706D6B")
        }
        let text = UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor.white : UIColor(hex: "706D6B")
        }
    }
}
