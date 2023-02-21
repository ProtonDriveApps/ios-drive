//
//  TableViewCell+helper.swift
//  ProtonCore-UIFoundations - Created on 23.07.20.
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
public protocol LineSeparatable {
    func addSeparator(padding: CGFloat) -> UIView
    func addSeparator(leftRef: UIView, constant: CGFloat) -> UIView
}

public extension LineSeparatable where Self: UIView {
    /// Add separator at bottom of view cell
    @discardableResult
    func addSeparator(padding: CGFloat = 16) -> UIView {
        let line = UIView()
        addSubview(line)
        line.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            line.leadingAnchor.constraint(equalTo: leadingAnchor, constant: padding),
            line.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -padding),
            line.bottomAnchor.constraint(equalTo: bottomAnchor),
            line.heightAnchor.constraint(equalToConstant: 1)
        ])
        line.backgroundColor = ColorProvider.SeparatorNorm
        return line
    }

    /// Add separator at bottom of view cell
    @discardableResult
    func addSeparator(leftRef: UIView, constant: CGFloat) -> UIView {
        let line = UIView()
        addSubview(line)
        line.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            line.leadingAnchor.constraint(equalTo: leftRef.leadingAnchor, constant: constant),
            line.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 0),
            line.bottomAnchor.constraint(equalTo: bottomAnchor),
            line.heightAnchor.constraint(equalToConstant: 1)
        ])
        line.backgroundColor = ColorProvider.SeparatorNorm
        return line
    }
}

extension UITableViewCell: LineSeparatable {}
