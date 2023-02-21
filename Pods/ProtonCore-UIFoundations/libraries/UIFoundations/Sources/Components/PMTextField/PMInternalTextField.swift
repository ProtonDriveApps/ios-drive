//
//  TextInsetTextField.swift
//  ProtonCore-UIFoundations - Created on 03/11/2020.
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

public protocol PMInternalTextFieldDelegate: AnyObject {
    func didClearEditing()
}

final class PMInternalTextField: UITextField {

    // MARK: - Properties
    weak var internalDelegate: PMInternalTextFieldDelegate?
    
    var isError: Bool = false {
        didSet {
            setBorder()
        }
    }

    override var isSecureTextEntry: Bool {
        didSet {
            guard isSecureTextEntry else {
                rightView = nil
                rightViewMode = .never
                return
            }

            showMaskButton()
        }
    }

    var suffixMarging: CGFloat = 0

    private let topBottomInset: CGFloat = 13
    private let leftRightInset: CGFloat = 12

    private lazy var unmaskButton: UIButton = {
        let button = UIButton(type: .custom)
        button.frame = CGRect(x: 0, y: 0, width: 24, height: 24)
        button.addTarget(self, action: #selector(self.togglePasswordVisibility), for: .touchUpInside)
        return button
    }()
    
    private lazy var clearButton: UIButton = {
        let button = UIButton(type: .custom)
        button.frame = CGRect(x: 0, y: 0, width: 24, height: 24)
        button.addTarget(self, action: #selector(self.clearContent), for: .touchUpInside)
        return button
    }()

    // MARK: - Setup

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        layer.masksToBounds = true
        layer.cornerRadius = 8
        layer.borderWidth = 1
        layer.borderColor = ColorProvider.InteractionWeakDisabled
    }
    
    var isUmnaskButton: Bool {
        return unmaskButton.image(for: .normal) != nil
    }

    var clearMode: UITextField.ViewMode = .never {
        didSet {
            guard unmaskButton.image(for: .normal) == nil else { return }
            rightViewMode = clearMode
            switch clearMode {
            case .never, .unlessEditing:
                rightView = nil
            case .whileEditing, .always:
                clearButton.setImage(IconProvider.crossCircleFilled, for: .normal)
                clearButton.tintColor = ColorProvider.IconHint
                rightView = clearButton
            @unknown default:
                break
            }
        }
    }

    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        var rightPadding: CGFloat = 0
        if rightView != nil {
            rightPadding += 30
        }
        return CGRect(x: bounds.origin.x + topBottomInset, y: bounds.origin.y + leftRightInset, width: bounds.size.width - 2 * leftRightInset - rightPadding - suffixMarging, height: bounds.size.height - 2 * topBottomInset)
    }

    override func textRect(forBounds bounds: CGRect) -> CGRect {
        return CGRect(x: bounds.origin.x + topBottomInset, y: bounds.origin.y + leftRightInset, width: bounds.size.width - 2 * leftRightInset - suffixMarging, height: bounds.size.height - 2 * topBottomInset)
    }

    override func rightViewRect(forBounds bounds: CGRect) -> CGRect {
        var rect = super.rightViewRect(forBounds: bounds)
        rect.origin.x -= 15
        return rect
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        setBorder()
    }

    // MARK: - Actions

    func setBorder() {
        if isError {
            layer.borderColor = ColorProvider.NotificationError
            return
        }

        layer.borderColor = isEditing ? ColorProvider.BrandNorm : ColorProvider.InteractionWeakDisabled
    }

    @objc private func togglePasswordVisibility() {
        isSecureTextEntry = !isSecureTextEntry

        showMaskButton()

        if let existingText = text, isSecureTextEntry {
            /* When toggling to secure text, all text will be purged if the user
             continues typing unless we intervene. This is prevented by first
             deleting the existing text and then recovering the original text. */
            deleteBackward()

            if let textRange = textRange(from: beginningOfDocument, to: endOfDocument) {
                replace(textRange, withText: existingText)
            }
        }

        /* Reset the selected text range since the cursor can end up in the wrong
         position after a toggle because the text might vary in width */
        if let existingSelectedTextRange = selectedTextRange {
            selectedTextRange = nil
            selectedTextRange = existingSelectedTextRange
        }
    }
    
    @objc private func clearContent() {
        text = ""
        internalDelegate?.didClearEditing()
    }

    private func showMaskButton() {
        unmaskButton.setImage(isSecureTextEntry ? IconProvider.eye : IconProvider.eyeSlash, for: .normal)
        unmaskButton.tintColor = ColorProvider.IconHint
        rightViewMode = .always
        rightView = unmaskButton
    }
}
