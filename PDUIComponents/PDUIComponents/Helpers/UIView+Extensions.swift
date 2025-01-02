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

#if canImport(UIKit)
import UIKit
#endif

#if os(iOS)
public extension UIView {
    func constrainBySuperviewBounds(padding: CGFloat) {
        guard let superview = superview else { return }
        NSLayoutConstraint.activate([
            topAnchor.constraint(greaterThanOrEqualTo: superview.safeAreaLayoutGuide.topAnchor, constant: padding),
            bottomAnchor.constraint(lessThanOrEqualTo: superview.safeAreaLayoutGuide.bottomAnchor, constant: -padding),
            leftAnchor.constraint(greaterThanOrEqualTo: superview.safeAreaLayoutGuide.leftAnchor, constant: padding),
            rightAnchor.constraint(lessThanOrEqualTo: superview.safeAreaLayoutGuide.rightAnchor, constant: -padding)
        ])
    }
}
#endif
