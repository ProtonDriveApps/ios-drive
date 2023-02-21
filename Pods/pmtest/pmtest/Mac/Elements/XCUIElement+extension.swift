//
//  XCUIElement+extension.swift
//  pmtestMac
//
//  Created by Robert Patchett on 11.10.22.
//

import AppKit
import XCTest

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
