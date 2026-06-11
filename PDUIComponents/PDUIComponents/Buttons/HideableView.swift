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

#if canImport(AppKit)

import SwiftUI

/// Displays one of two views, depending on whether a modifier key is pressed.
public struct HideableView<T: View, U: View>: View {
    @State var modifierStateMonitor: Any?
    @State private var isModifierPressed = false

    private let modifier: NSEvent.ModifierFlags
    private let defaultView: () -> T
    private let pressedView: () -> U

    public init(modifier: NSEvent.ModifierFlags, defaultView: @escaping () -> T, pressedView: @escaping () -> U) {
        self.modifier = modifier
        self.defaultView = defaultView
        self.pressedView = pressedView
    }

    public var body: some View {
        VStack {
            if isModifierPressed {
                pressedView()
            } else {
                defaultView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSEvent.didChangeKeyStateNotification)) { notification in
            if let event = notification.object as? NSEvent {
                withAnimation {
                    isModifierPressed = event.modifierFlags.contains(modifier)
                }
            }
        }
        .onAppear {
            self.modifierStateMonitor = NSEvent.startModifierStateMonitor()
        }
        .onDisappear {
            if let modifierStateMonitor {
                NSEvent.removeMonitor(modifierStateMonitor)
            }
        }
    }
}

extension NSEvent {
    static let didChangeKeyStateNotification = Notification.Name("NSEventDidChangeKeyState")

    static func startModifierStateMonitor() -> Any? {
        NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { event in
            NotificationCenter.default.post(name: didChangeKeyStateNotification, object: event)
            return event
        }
    }
}

#endif
