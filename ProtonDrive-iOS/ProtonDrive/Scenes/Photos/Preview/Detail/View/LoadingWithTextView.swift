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

import ProtonCore_UIFoundations
import UIKit

final class LoadingWithTextView: UIView {
    init(text: String) {
        super.init(frame: .zero)
        setupLayout(with: text)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout(with text: String) {
        let label = UILabel(text, font: .preferredFont(forTextStyle: .body), textColor: ColorProvider.TextInverted)
        let activity = UIActivityIndicatorView(style: .medium)
        activity.color = ColorProvider.TextInverted
        activity.startAnimating()
        let stackView = UIStackView(arrangedSubviews: [activity, label])
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 12
        stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
        stackView.isLayoutMarginsRelativeArrangement = true
        addSubview(stackView)
        stackView.fillSuperview()
        backgroundColor = ColorProvider.FloatyBackground
        roundCorner(8)
    }
}
