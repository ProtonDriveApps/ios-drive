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

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

#if os(iOS)
extension UIApplication {
    public func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

public extension UIApplication {
    
    /// Modifies color of status bar if current key window has a ``ContentHostingController`` as a root
    class func setStatusBarStyle(_ style: UIStatusBarStyle) {
        if let vc = UIApplication.getKeyWindow()?.rootViewController as? ContentHostingControllerProtocol {
            vc.changeStatusBarStyle(style)
        }
    }
    
    private class func getKeyWindow() -> UIWindow? {
        return UIApplication.shared.windows.first{ $0.isKeyWindow }
    }
}

public protocol ContentHostingControllerProtocol {
    func changeStatusBarStyle(_ style: UIStatusBarStyle)
}

/// Subclass of UIHostingController that can modify color of status bar. Should be root ViewController in the key window
public class ContentHostingController<Content>: UIHostingController<Content>, ContentHostingControllerProtocol where Content: View {
      
    private var currentStatusBarStyle: UIStatusBarStyle = .default

    public override var preferredStatusBarStyle: UIStatusBarStyle {
        currentStatusBarStyle
    }
    
    public override init(rootView: Content) {
        super.init(rootView: rootView)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    public func changeStatusBarStyle(_ style: UIStatusBarStyle) {
        self.currentStatusBarStyle = style
        self.setNeedsStatusBarAppearanceUpdate()
    }
    
    public override func setNeedsStatusBarAppearanceUpdate() {
        UIView.animate(withDuration: 0.35, animations: {
            super.setNeedsStatusBarAppearanceUpdate()
        })
    }
}
#endif
