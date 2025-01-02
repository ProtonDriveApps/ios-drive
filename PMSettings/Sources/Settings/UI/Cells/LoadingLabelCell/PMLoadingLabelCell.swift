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

import UIKit
import ProtonCoreUIFoundations

class PMLoadingLabelCell: PMSettingsBaseCell {
    lazy var stack = UIStackView(.horizontal, alignment: .center, distribution: .fill, spacing: 8)
    lazy var label = UILabel.makeLabel()
    lazy var activityIndicator = UIActivityIndicatorView(style: .medium)

    private var action: (() async throws -> Void)?
    private var isLoading = false

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        contentView.addSubview(stack)
        stack.fillSuperviewWithConstraints(margin: 16)

        stack.addArrangedSubview(label)
        stack.addArrangedSubview(activityIndicator)

        selectionStyle = .none
        activityIndicator.color = ColorProvider.BrandNorm
        activityIndicator.isHidden = true

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(onCellTapped))
        contentView.addGestureRecognizer(tapGesture)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        label.text = nil
        action = nil
        activityIndicator.stopAnimating()
        activityIndicator.isHidden = true
        isLoading = false
        contentView.backgroundColor = .clear
    }

    @objc private func onCellTapped() {
        guard let action = action, !isLoading else { return }
        isLoading = true
        contentView.backgroundColor = UIColor.systemGray5
        activityIndicator.isHidden = false
        activityIndicator.startAnimating()

        Task {
            try? await action()
            setCellLoading()
        }
    }

    @MainActor
    func setCellLoading() {
        self.activityIndicator.stopAnimating()
        self.activityIndicator.isHidden = true
        self.contentView.backgroundColor = .clear
        self.isLoading = false
    }

    func configureCell(with model: PMLoadingLabelConfiguration, hasSeparator: Bool) {
        label.text = model.text.localized(in: model.bundle)
        action = model.action
        addSeparatorIfNeeded(hasSeparator)
        backgroundColor = ColorProvider.BackgroundNorm
    }
}

private extension UILabel {
    class func makeLabel() -> UILabel {
        let label = UILabel(LabelStyles.body)
        label.numberOfLines = 0
        return label
    }
}
