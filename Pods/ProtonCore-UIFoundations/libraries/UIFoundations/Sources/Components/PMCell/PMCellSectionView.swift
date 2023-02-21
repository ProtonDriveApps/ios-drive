//
//  PMCellSectionView.swift
//  ProtonCore-UIFoundations - Created on 16.12.2020.
//
//  Copyright (c) 2022 Proton Technologies AG
//
//  This file is part of Proton Technologies AG and ProtonCore.
//
//  ProtonCore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonCore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonCore.  If not, see <https://www.gnu.org/licenses/>.

import UIKit
import ProtonCore_Foundations

public final class PMCellSectionView: UITableViewHeaderFooterView, AccessibleView {

    public static let reuseIdentifier = "PMCellSectionView"
    public static let nib = UINib(nibName: "PMCellSectionView", bundle: PMUIFoundations.bundle)

    // MARK: - Outlets

    @IBOutlet private weak var titleLabel: UILabel!

    // MARK: - Properties

    public var title: String? {
        didSet {
            titleLabel.text = title
        }
    }

    override public func awakeFromNib() {
        super.awakeFromNib()

        titleLabel.textColor = ColorProvider.TextWeak
        titleLabel.font = .adjustedFont(forTextStyle: .body)
        contentView.backgroundColor = UIColor.dynamic(light: .white, dark: .black)
        generateAccessibilityIdentifiers()
    }
}
