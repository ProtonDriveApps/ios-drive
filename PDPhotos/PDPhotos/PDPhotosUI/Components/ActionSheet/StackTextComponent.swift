// Copyright (c) 2025 Proton AG
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

struct StackTextComponent: PMActionSheetComponent {
    typealias Element = UIView

    // [up, right, bottom, left]
    let edge: [CGFloat?]
    let offset: UIOffset?
    let title: String
    let subtitle: String

    init(edge: [CGFloat?], offset: UIOffset?, title: String, subtitle: String) {
        self.edge = edge
        self.offset = offset
        self.title = title
        self.subtitle = subtitle
    }

    func makeElement() -> Element {
        let container = UIStackView()
        container.axis = .vertical
        let titleLabel = UILabel(title, font: .systemFont(ofSize: 15), textColor: ColorProvider.TextNorm)
        let subtitleLabel = UILabel(subtitle, font: .systemFont(ofSize: 13), textColor: ColorProvider.TextHint)

        container.addArrangedSubview(titleLabel)
        container.addArrangedSubview(subtitleLabel)
        container.translatesAutoresizingMaskIntoConstraints = false
        return container
    }
}
