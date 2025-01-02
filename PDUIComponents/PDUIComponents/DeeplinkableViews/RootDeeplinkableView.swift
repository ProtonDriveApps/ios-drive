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
public struct RootDeeplinkableView<Content: View>: View {
    var contents: Content
    var navigationTracker: UINavigationControllerDelegate?
    
    public init(navigationTracker: UINavigationControllerDelegate?, @ViewBuilder contents: () -> Content) {
        self.navigationTracker = navigationTracker
        self.contents = contents()
    }
    
    var navigationBarAccessor: some View {
        NavigationControllerAccessor(movedToParentCallback: {
            $0.delegate = self.navigationTracker
           
            // movedToParentCallback is called when NavigationView already has a contents view inside
            // so we need to compensate both onAppear calls for it
            if let root = $0.viewControllers.first {
                $0.delegate?.navigationController?($0, willShow: root, animated: false)
                $0.delegate?.navigationController?($0, didShow: root, animated: false)
            }
        })
    }
    
    public var body: some View {
        NavigationView {
            contents
            .background(navigationBarAccessor)
        }.navigationViewStyle(StackNavigationViewStyle())
    }
}
#endif
