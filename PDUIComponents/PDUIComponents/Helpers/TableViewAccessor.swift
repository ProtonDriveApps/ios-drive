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
struct TableViewAccessor: UIViewRepresentable, Equatable {
    static func == (lhs: TableViewAccessor, rhs: TableViewAccessor) -> Bool {
        lhs.isVisible == rhs.isVisible
    }
    
    var isVisible: Bool
    var handler: (UITableView?) -> Void
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        let superview = uiView.findViewController()?.view
        
        let tableView = superview?.subview(of: UITableView.self)
        handler(tableView)
    }
}

extension View {
    func accessUnderlyingTableView(isVisible: Bool, handler: @escaping (UITableView?) -> Void) -> some View {
        self.overlay(
            TableViewAccessor(isVisible: isVisible, handler: handler)
            .allowsHitTesting(false)
            .frame(width: 0, height: 0)
        )
    }
}

extension UIView {
    func subview<T>(of type: T.Type) -> T? {
        return subviews.compactMap { $0 as? T ?? $0.subview(of: type) }.first
    }
    
    func findViewController() -> UIViewController? {
        if let nextResponder = self.next as? UIViewController {
            return nextResponder
        } else if let nextResponder = self.next as? UIView {
            return nextResponder.findViewController()
        } else {
            return nil
        }
    }
}
#endif
