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
import UIKit
import Combine

public protocol PMSlidingContainer: UIViewController {
    /// Handler that is called whenever side menu is being revealed or closed. Default value is `nil`.
    /// - Parameters:
    ///     - Bool: whether menu will be releavled or hidden by the end of current action
    var onMenuToggle: ((Bool) -> Void)? { get set }
    
    /// Public constructor for `PMSlidingContainerViewController`. In current implementation invokes global configuration of underlaying 3rd party objects.
    /// - Parameters:
    ///     - skeleton: view controller that will be presented in content area before menu controller receives first navigation action
    ///     - menu: view controller with menu table
    ///     - togglePublisher: publisher that receives events whenever rest of app needs to reveal the menu
    init(skeleton: UIViewController, menu: UIViewController, togglePublisher: NotificationCenter.Publisher?)
    
    /// Changes view controller in the content area.
    func setContent(to destination: UIViewController)
    
    /// Reveals side menu if it is hidden, otherwise does nothing.
    func revealMenu()
}

public enum PMSlidingContainerComposer {
    public static func makePMSlidingContainer(skeleton: UIViewController, menu: UIViewController, togglePublisher: NotificationCenter.Publisher?) -> some PMSlidingContainer {
        PMSlidingContainerViewController(skeleton: skeleton, menu: menu, togglePublisher: togglePublisher)
    }
}
