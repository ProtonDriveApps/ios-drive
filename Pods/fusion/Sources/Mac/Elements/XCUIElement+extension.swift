//
//  XCUIElement+extension.swift
//  fusionMac
//
//  Created by Robert Patchett on 11.10.22.
//

#if os(OSX)
import XCTest
import AppKit

extension XCUIElement {
    /**
     * Pastes a full string of text into a textfield instead of typing each char.
     */
    func pasteText(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        self.typeKey("v", modifierFlags: .command)
    }
}

extension UIElement {

    @discardableResult
    public func pasteText(_ text: String) -> UIElement {
        uiElement()!.pasteText(text)
        return self
    }
}
#endif
