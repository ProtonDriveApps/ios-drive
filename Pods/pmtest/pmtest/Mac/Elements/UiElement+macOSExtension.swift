//
//  UIElement+macOSExtension.swift
//  pmtestMac
//
//  Created by Robert Patchett on 11.10.22.
//

import XCTest

extension UIElement {

    @discardableResult
    public func pasteText(_ text: String) -> UIElement {
        uiElement()!.pasteText(text)
        return self
    }
}
