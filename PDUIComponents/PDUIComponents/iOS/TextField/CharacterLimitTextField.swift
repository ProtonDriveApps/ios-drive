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

#if os(iOS)
import Foundation
import SwiftUI
import ProtonCoreUIFoundations

/// PMTextField wrapper for char limitation
public struct CharacterLimitTextField: UIViewRepresentable {
    @Binding var isEnabled: Bool
    @Binding var text: String
    let isPassword: Bool
    let maximumChars: Int
    let placeholder: String
    let title: String
    
    public init(
        isEnabled: Binding<Bool>,
        text: Binding<String>,
        isPassword: Bool = true,
        maximumChars: Int,
        placeholder: String,
        title: String
    ) {
        self._isEnabled = isEnabled
        self._text = text
        self.isPassword = isPassword
        self.maximumChars = maximumChars
        self.placeholder = placeholder
        self.title = title
    }
    
    public func makeCoordinator() -> CharacterLimitTextFieldCoordinator {
        CharacterLimitTextFieldCoordinator(textBinding: $text, maximumChars: maximumChars)
    }
    
    public func makeUIView(context: Context) -> PMTextField {
        let view = PMTextField()
        view.title = title
        view.placeholder = placeholder
        view.delegate = context.coordinator
        view.isPassword = isPassword
        view.textContentType = .dateTime
        
        return view
    }
    
    public func updateUIView(_ uiView: PMTextField, context: Context) {
        uiView.value = text
        uiView.isEnabled = isEnabled
    }
}

public final class CharacterLimitTextFieldCoordinator: NSObject, PMTextFieldDelegate, UITextFieldDelegate {
    let textBinding: Binding<String>
    let maximumChars: Int
    
    init(textBinding: Binding<String>, maximumChars: Int) {
        self.textBinding = textBinding
        self.maximumChars = maximumChars
    }
    
    public func didEndEditing(textField: PMTextField) {
        
    }
    
    public func textFieldShouldReturn(_ textField: PMTextField) -> Bool {
        return true
    }
    
    public func didBeginEditing(textField: PMTextField) {
        
    }
    
    public func didChangeValue(_ textField: PMTextField, value: String) {
        let isOverCharLimit = value.count > maximumChars
        textField.isError = isOverCharLimit
        if isOverCharLimit {
            textField.errorMessage = "\(value.count)/\(maximumChars)"
        } else {
            textField.errorMessage = ""
            textField.assistiveText = "\(value.count)/\(maximumChars)"
        }
        textBinding.wrappedValue = value
    }
}

#endif
