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

import ProtonCoreUIFoundations
#if canImport(UIKit)
import UIKit
#endif

#if os(iOS)
public final class CloseBarButton: UIBarButtonItem {
    private var block: (() -> Void)?

    public init(block: @escaping () -> Void) {
        self.block = block
        let button = UIButton(frame: .zero)
        button.setSizeContraint(height: 24, width: 24)
        button.tintColor = ColorProvider.IconNorm
        button.setBackgroundImage(IconProvider.cross, for: .normal)
        button.accessibilityIdentifier = "SimpleCloseButtonView.Button.Close"
        super.init()
        customView = button
        button.addTarget(self, action: #selector(onTap), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func onTap() {
        block?()
    }
}
#endif
