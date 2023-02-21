//
//  NSAttributedString+Link.swift
//  ProtonCore-Login - Created on 11/03/2021.
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

import Foundation
import UIKit

extension NSAttributedString {
    @available(*, deprecated, message: "Please Find the replacement in UIFoundation")
    static func hyperlink(path: String, in string: String, as substring: String, alignment: NSTextAlignment = .left, font: UIFont?) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        let nsString = NSString(string: string.lowercased())
        let substringRange = nsString.range(of: substring.lowercased())
        let attributerString = NSMutableAttributedString(string: string, attributes: [NSAttributedString.Key.paragraphStyle: paragraphStyle])
        attributerString.addAttribute(.link, value: path, range: substringRange)
        if let font = font {
            attributerString.addAttribute(.font, value: font, range: nsString.range(of: string))
        }
        return attributerString
    }
}
