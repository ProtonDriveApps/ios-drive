// Copyright (c) 2025 Proton AG
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

import UIKit
import Combine
import PDCore
import ProtonCoreUIFoundations

final class DebugOverlayController {
    private var window: FloatingButtonWindow?
    private var cancellables = Set<AnyCancellable>()
    private let localSettings: LocalSettings
    private let factory: BugReportFactoryProtocol
    private var longPressTimer: Timer?

    init(localSettings: LocalSettings, factory: BugReportFactoryProtocol) {
        self.localSettings = localSettings
        self.factory = factory
        observeDebugModeEnabled(from: localSettings)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenshot),
            name: UIApplication.userDidTakeScreenshotNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCaptureChange),
            name: UIScreen.capturedDidChangeNotification,
            object: UIScreen.main
        )

        if UIScreen.main.isCaptured {
            Log.debug("🟡 Screen is being recorded or mirrored at launch", domain: .logs)
        }
    }
    private func observeDebugModeEnabled(from localSettings: LocalSettings) {
        localSettings.publisher(for: \.debugModeEnabled)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                enabled ? self?.showOverlay() : self?.hideOverlay()
            }
            .store(in: &cancellables)
    }

    private func showOverlay() {
        guard window == nil else { return }

        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else {
            Log.warning("🟡 No active window scene for DebugOverlay", domain: .logs)
            return
        }

        let debugWindow = FloatingButtonWindow(windowScene: scene)
        debugWindow.windowLevel = .statusBar + 100
        debugWindow.backgroundColor = .clear
        debugWindow.rootViewController = UIViewController()
        debugWindow.isHidden = false

        // Add button
        let button = UIButton(type: .custom)
        button.backgroundColor = .yellow
        button.setImage(IconProvider.bug, for: .normal)
        button.tintColor = ColorProvider.IconWeak
        button.layer.cornerRadius = 30
        let brandColor: UIColor = ColorProvider.BrandNorm
        button.layer.shadowColor = brandColor.cgColor
        button.layer.shadowOpacity = 0.25
        button.layer.shadowRadius = 8
        button.frame = CGRect(x: scene.screen.bounds.width - 90, y: scene.screen.bounds.height - 120, width: 60, height: 60)

        debugWindow.addSubview(button)
        debugWindow.button = button

        // Add tap handler (short press)
        button.addAction(UIAction { _ in
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            Log.debug("🟡 Issue reported by the user", domain: .logs)
        }, for: .touchUpInside)

        // Add drag (pan gesture)
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        button.addGestureRecognizer(panGesture)

        // Add long press
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 2.0
        button.addGestureRecognizer(longPress)

        window = debugWindow
    }

    private func hideOverlay() {
        window?.resignKey()
        window?.isHidden = true
        window = nil
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard
            let button = gesture.view,
            let debugWindow = button.window
        else { return }

        let translation = gesture.translation(in: debugWindow)
        if gesture.state == .changed {
            let newCenter = CGPoint(
                x: button.center.x + translation.x,
                y: button.center.y + translation.y
            )
            button.center = newCenter
            gesture.setTranslation(.zero, in: debugWindow)
        }
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            Log.debug("🟡 Debug button long-pressed", domain: .logs)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            let vc = factory.makeBugReportViewController()
            let topVC = UIApplication.shared.topMostViewControllerFromAppWindow()
            topVC?.present(vc, animated: true)
        }
    }

    @objc private func handleScreenshot() {
        Log.debug("🟡 Screenshot taken", domain: .logs)
    }

    @objc private func handleCaptureChange() {
        if UIScreen.main.isCaptured {
            Log.debug("🟡 Screen recording started", domain: .logs)
        } else {
            Log.debug("🟡 Screen recording stopped", domain: .logs)
        }
    }
}
