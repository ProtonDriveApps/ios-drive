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
import SwiftUI
import UIKit

public struct EnhancedTextField: UIViewRepresentable {
    let placeholder: String // text field placeholder
    @Binding var text: String // input binding
    let onBackspace: (Bool) -> Void // true if backspace on empty input
    let onSubmit: () -> Void
    
    public init(
        placeholder: String,
        text: Binding<String>,
        onBackspace: @escaping (Bool) -> Void,
        onSubmit: @escaping () -> Void
    ) {
        self.placeholder = placeholder
        self._text = text
        self.onBackspace = onBackspace
        self.onSubmit = onSubmit
    }
    
    public func makeCoordinator() -> EnhancedTextFieldCoordinator {
        EnhancedTextFieldCoordinator(textBinding: $text, onSubmit: onSubmit)
    }
    
    public func makeUIView(context: Context) -> EnhancedUITextField {
        let view = EnhancedUITextField()
        view.placeholder = placeholder
        view.delegate = context.coordinator
        return view
    }
    
    public func updateUIView(_ uiView: EnhancedUITextField, context: Context) {
        uiView.text = text
        uiView.onBackspace = onBackspace
    }
    
    // custom UITextField subclass that detects backspace events
    public final class EnhancedUITextField: UITextField {
        var onBackspace: ((Bool) -> Void)?
        
        override init(frame: CGRect) {
            onBackspace = nil
            super.init(frame: frame)
            autocorrectionType = .no
            autocapitalizationType = .none
            keyboardType = .emailAddress
        }
        
        required init?(coder: NSCoder) {
            fatalError()
        }
        
        override public func deleteBackward() {
            onBackspace?(text?.isEmpty == true)
            super.deleteBackward()
        }
    }
}

// the coordinator is here to allow for mapping text to the
// binding using the delegate methods
public final class EnhancedTextFieldCoordinator: NSObject {
    let textBinding: Binding<String>
    let onSubmit: () -> Void
    
    init(textBinding: Binding<String>, onSubmit: @escaping () -> Void) {
        self.textBinding = textBinding
        self.onSubmit = onSubmit
    }
}

extension EnhancedTextFieldCoordinator: UITextFieldDelegate {
    public func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        let text = textField.text ?? ""
        let newText = (text as NSString).replacingCharacters(in: range, with: string)
        textBinding.wrappedValue = newText
        return true
    }
    
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        onSubmit()
        return true
    }
}
#endif
