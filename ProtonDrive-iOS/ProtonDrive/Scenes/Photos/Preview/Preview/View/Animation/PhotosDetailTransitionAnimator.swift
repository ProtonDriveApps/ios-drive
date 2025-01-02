// Copyright (c) 2024 Proton AG
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

final class PhotosDetailTransitionAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    private static let duration = 0.45

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return PhotosDetailTransitionAnimator.duration
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let presentedViewController = transitionContext.viewController(forKey: .from) else {
            return
        }

        let transform = CGAffineTransform(translationX: 0, y: transitionContext.containerView.bounds.height)

        UIView.animate(withDuration: PhotosDetailTransitionAnimator.duration, delay: 0, options: .curveEaseOut, animations: {
            presentedViewController.view.transform = transform
        }, completion: { (success) in
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        })
    }
}
