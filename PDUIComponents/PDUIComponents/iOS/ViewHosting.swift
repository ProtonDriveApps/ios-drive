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
public final class ViewHosting<Content: View>: UIView {

    private var hostingController: UIHostingController<Content>?

    public init(@ViewBuilder _ content: () -> Content) {
        super.init(frame: .zero)

        let hostingController = UIHostingController(rootView: content())
        self.hostingController = hostingController

        // Add the hosting controller's view as a subview
        backgroundColor = .clear
        addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = .clear

        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: self.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
#endif
