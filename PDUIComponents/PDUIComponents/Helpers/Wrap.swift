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
struct Wrap<Wrapped: UIView>: UIViewRepresentable {
    typealias Updater = (Wrapped, Context) -> Void

    var makeView: () -> Wrapped
    var update: (Wrapped, Context) -> Void

    init(_ makeView: @escaping @autoclosure () -> Wrapped,
         updater update: @escaping Updater) {
        self.makeView = makeView
        self.update = update
    }

    func makeUIView(context: Context) -> Wrapped {
        makeView()
    }

    func updateUIView(_ view: Wrapped, context: Context) {
        update(view, context)
    }
}

extension Wrap {
    init(_ makeView: @escaping @autoclosure () -> Wrapped,
         updater update: @escaping (Wrapped) -> Void) {
        self.makeView = makeView
        self.update = { view, _ in update(view) }
    }

    init(_ makeView: @escaping @autoclosure () -> Wrapped) {
        self.makeView = makeView
        self.update = { _, _ in }
    }
}
#endif
