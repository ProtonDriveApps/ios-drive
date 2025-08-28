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

// Native back button is disabled in the AlbumDetailView
// As a result, the swipe back gesture is also disabled.
// This class is designed to re-enable the swipe back gesture.
final class SwipeBackRecognizerDelegate: NSObject, UIGestureRecognizerDelegate {
    private weak var navigationController: UINavigationController?
    private weak var originalDelegate: (any UIGestureRecognizerDelegate)?
    private var isEnabled = false

    init(navigationController: UINavigationController?) {
        originalDelegate = navigationController?.interactivePopGestureRecognizer?.delegate
        self.navigationController = navigationController
        super.init()
        navigationController?.interactivePopGestureRecognizer?.delegate = self
    }

    deinit {
        navigationController?.interactivePopGestureRecognizer?.delegate = originalDelegate
    }

    func enableSwipeGesture(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if isEnabled {
            let count = navigationController?.viewControllers.count ?? 0
            return count > 1
        } else {
            return false
        }
    }
}
