//
//  PMActionBarItem.swift
//  ProtonCore-UIFoundations - Created on 29.07.20.
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

public enum PMActionBarItemType {
    ///
    case label
    case button
    case separator
}

public struct PMActionBarItem {
    private(set) var icon: UIImage?
    private(set) var text: String?
    /// The technique to use for aligning the text.
    private(set) var alignment: NSTextAlignment = .left
    /// Color of bar item content, default value is `ColorProvider.FloatyText`
    private(set) var itemColor: UIColor
    /// Color of bar item content when item is selected.
    private(set) var selectedItemColor: UIColor?
    /// Background color of bar item.
    private(set) var backgroundColor: UIColor
    /// Color when bar item is selected.
    private(set) var selectedBgColor: UIColor?
    /// A Boolean value indicating whether the control is in the selected state.
    var isSelected: Bool = false
    /// Type of bar item
    private(set) var type: PMActionBarItemType
    /// A block to execute when the user selects the action.
    private(set) var handler: ((PMActionBarItem) -> Void)?
    /// Optional information about the the bar item.
    public private(set) var userInfo: [String: Any]?
    /// A Boolean value indicating whether the control is in the pressed state.
    /// In this state, the activity indicator will spin if the shouldSpin set as true.
    /// But if shouldSpin is false, then isPressed is always false.
    /// # Notes
    /// Changing value here won't stop the animation
    public var isPressed: Bool = false
    /// A Boolean value indicating whether the control should spin once it's selected. Default false.
    var shouldSpin: Bool = false
    /// Color when bar item is pressed
    var pressedBackgroundColor: UIColor?
    private(set) var activityIndicator: UIActivityIndicatorView?

    /// Initializer of bar item(button type)
    /// - Parameters:
    ///   - icon: Icon of bar item
    ///   - itemColor: Color of bar item content, default value is `ColorProvider.FloatyText`
    ///   - selectedItemColor: Color of bar item content when item is selected.
    ///   - backgroundColor: Background color of bar item, default value is `ColorProvider.FloatyBackground`
    ///   - selectedBgColor: Background color when bar item is selected.
    ///   - isSelected: A Boolean value indicating whether the control is in the selected state.
    ///   - userInfo: Optional information about the the bar item.
    ///   - handler: A block to execute when the user selects the action.
    public init(icon: UIImage,
                itemColor: UIColor = ColorProvider.FloatyText,
                selectedItemColor: UIColor? = nil,
                backgroundColor: UIColor = ColorProvider.FloatyBackground,
                selectedBgColor: UIColor? = nil,
                isSelected: Bool = false,
                userInfo: [String: Any]? = nil,
                handler: ((PMActionBarItem) -> Void)?) {
        self.icon = icon
        self.itemColor = itemColor
        self.selectedItemColor = selectedItemColor
        self.backgroundColor = backgroundColor
        self.selectedBgColor = selectedBgColor
        self.handler = handler
        self.userInfo = userInfo
        self.type = .button
        self.isSelected = isSelected
    }

    /// Initializer of bar item(label type)
    /// - Parameters:
    ///   - text: Text of bar item
    ///   - alignment: The technique to use for aligning the text.
    ///   - itemColor: Color of bar item content, default value is `ColorProvider.FloatyText`
    ///   - backgroundColor: Background color of bar item, default value is `.clear`
    public init(text: String,
                alignment: NSTextAlignment = .left,
                itemColor: UIColor = ColorProvider.FloatyText,
                backgroundColor: UIColor = .clear) {
        self.text = text
        self.alignment = alignment
        self.itemColor = itemColor
        self.selectedItemColor = nil
        self.backgroundColor = backgroundColor
        self.selectedBgColor = nil
        self.userInfo = nil
        self.handler = nil
        self.type = .label
    }

    /// Initializer of bar item(button type)
    /// - Parameters:
    ///   - text: Text of bar item
    ///   - alignment: The technique to use for aligning the text.
    ///   - itemColor: Color of bar item content, default value is `ColorProvider.FloatyText`
    ///   - selectedItemColor: Color of bar item content when item is selected.
    ///   - backgroundColor: Background color of bar item, default value is `.clear`
    ///   - selectedBgColor: Background color when bar item is selected.
    ///   - isSelected: A Boolean value indicating whether the control is in the selected state.
    ///   - userInfo: Optional information about the the bar item.
    ///   - handler: A block to execute when the user selects the action.
    public init(text: String,
                itemColor: UIColor = ColorProvider.FloatyText,
                selectedItemColor: UIColor? = nil,
                backgroundColor: UIColor = .clear,
                selectedBgColor: UIColor? = nil,
                isSelected: Bool = false,
                userInfo: [String: Any]? = nil,
                handler: ((PMActionBarItem) -> Void)?) {
        self.text = text
        self.alignment = .center
        self.itemColor = itemColor
        self.selectedItemColor = selectedItemColor
        self.backgroundColor = backgroundColor
        self.selectedBgColor = selectedBgColor
        self.userInfo = userInfo
        self.handler = handler
        self.type = .button
        self.isSelected = isSelected
    }

    /// Initializer of rich bar item(button type)
    /// - Parameters:
    ///   - icon: Icon of bar item
    ///   - text: Text of bar item
    ///   - itemColor: Color of bar item content, default value is `ColorProvider.FloatyText`
    ///   - selectedItemColor: Color of bar item content when item is selected.
    ///   - backgroundColor: Background color of bar item, default value is `.clear`
    ///   - selectedBgColor: Background color when bar item is selected.
    ///   - isSelected: A Boolean value indicating whether the control is in the selected state.
    ///   - userInfo: Optional information about the the bar item.
    ///   - handler: A block to execute when the user selects the action.
    public init(icon: UIImage,
                text: String,
                itemColor: UIColor = ColorProvider.FloatyText,
                selectedItemColor: UIColor? = nil,
                backgroundColor: UIColor = .clear,
                selectedBgColor: UIColor? = nil,
                isSelected: Bool = false,
                userInfo: [String: Any]? = nil,
                handler: ((PMActionBarItem) -> Void)?) {
        self.icon = icon
        self.text = text
        self.alignment = .center
        self.itemColor = itemColor
        self.selectedItemColor = selectedItemColor
        self.backgroundColor = backgroundColor
        self.selectedBgColor = selectedBgColor
        self.userInfo = userInfo
        self.handler = handler
        self.type = .button
        self.isSelected = isSelected
    }

    /// Initializer of separator
    /// - Parameters:
    ///   - width: width of separator
    ///   - verticalPadding: top padding and bottom padding
    ///   - color: color of spearator
    public init(width: CGFloat = 1,
                verticalPadding: CGFloat = 6,
                color: UIColor = ColorProvider.BackgroundSecondary) {
        self.itemColor = color
        self.backgroundColor = color
        self.type = .separator
        self.userInfo = ["width": width, "verticalPadding": verticalPadding]
    }
    
    /// Set should spin as true, there'd be an activity indicator spinning shen selecting the button.
    /// But it won't work on those already selected.
    public func setShouldSpin(pressedBackgroundColor: UIColor = ColorProvider.FloatyPressed) -> Self {
        var item = self
        guard self.shouldSpin == false else {
            return item
        }
        item.shouldSpin = true
        item.pressedBackgroundColor = pressedBackgroundColor
        
        item.activityIndicator = .init(style: .white)
        item.activityIndicator?.hidesWhenStopped = true
        item.activityIndicator?.isHidden = true
        return item
    }
}
