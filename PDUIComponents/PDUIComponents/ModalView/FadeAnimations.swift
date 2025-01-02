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

import ProtonCoreUIFoundations
import Foundation
#if canImport(UIKit)
import UIKit
#endif

private var fadeAnimationDuration: TimeInterval { 0.3 }

#if os(iOS)
final class FadeInAnimation: NSObject, UIViewControllerAnimatedTransitioning {
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        fadeAnimationDuration
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let container = transitionContext.containerView
        container.backgroundColor = .clear
        
        let child = transitionContext.viewController(forKey: .to)!
        child.view.backgroundColor = .clear
        child.view.frame = container.bounds
        child.view.frame.origin.y = container.bounds.height
        container.addSubview(child.view)
    
        UIView.animate(withDuration: self.transitionDuration(using: transitionContext)) {
            container.backgroundColor = ColorProvider.BlenderNorm
            child.view.frame = container.bounds
        } completion: { finished in
            transitionContext.completeTransition(finished)
        }
    }
}

final class FadeOutAnimation: NSObject, UIViewControllerAnimatedTransitioning {
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        fadeAnimationDuration
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let container = transitionContext.containerView
        let child = transitionContext.viewController(forKey: .from)!
    
        UIView.animate(withDuration: self.transitionDuration(using: transitionContext)) {
            container.backgroundColor = .clear
            child.view.frame.origin.y = container.bounds.height
        } completion: { finished in
            child.view.removeFromSuperview()
            transitionContext.completeTransition(finished)
        }
    }
}
#endif
