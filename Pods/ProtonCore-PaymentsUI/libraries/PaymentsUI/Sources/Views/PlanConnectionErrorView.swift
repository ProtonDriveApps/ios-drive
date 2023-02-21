//
//  PlanConnectionErrorView.swift
//  ProtonCore_PaymentsUI - Created on 01/06/2021.
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
import ProtonCore_UIFoundations
import ProtonCore_CoreTranslation

final class PlanConnectionErrorView: UIView {

    static let reuseIdentifier = "PlanConnectionErrorView"
    static let nib = UINib(nibName: "PlanConnectionErrorView", bundle: PaymentsUI.bundle)

    // MARK: - Outlets

    @IBOutlet var mainView: UIView! {
        didSet {
            mainView.backgroundColor = ColorProvider.BackgroundNorm
        }
    }
    @IBOutlet weak var iconImageView: UIImageView! {
        didSet {
            iconImageView.image = IconProvider.paymentsConnectivityIssues
        }
    }
    @IBOutlet weak var titleLabel: UILabel! {
        didSet {
            titleLabel.textColor = ColorProvider.TextNorm
            titleLabel.text = CoreString._new_plans_connection_error_title
        }
    }
    @IBOutlet weak var descriptionLabel: UILabel! {
        didSet {
            descriptionLabel.textColor = ColorProvider.TextWeak
            descriptionLabel.text = CoreString._new_plans_connection_error_description
        }
    }
    
    // MARK: - Properties
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        load()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        load()
    }

    private func load() {
        PaymentsUI.bundle.loadNibNamed(PlanConnectionErrorView.reuseIdentifier, owner: self, options: nil)
        addSubview(mainView)
        mainView.frame = bounds
        mainView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backgroundColor = ColorProvider.BackgroundNorm
    }
}
