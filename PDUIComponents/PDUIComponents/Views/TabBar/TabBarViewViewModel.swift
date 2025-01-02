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

public class TabBarViewViewModel: ObservableObject {
    /// Enforces hiding of tab bar, will case update of TabBarContainer
    @Published public var isTabBarHidden: Bool = false
    
    /// Enforces switch of tab, will cause update of TabBarContainer
    @Published public var activateTab: NavigationBarButtonViewModel
    
    /// Stores current state of TabBarContainer
    var currentTab: NavigationBarButtonViewModel
    
    public init(initialTab: NavigationBarButtonViewModel = .automatic) {
        self.activateTab = initialTab
        self.currentTab = .automatic
    }
}

extension TabBarViewViewModel: DeeplinkableScene {
    private static let ActiveTabKey = "ActiveTab"
    
    public struct RestorationInfo {
        public var activeTab: NavigationBarButtonViewModel
    }
    
    public func buildStateRestorationActivity() -> NSUserActivity {
        let activity = self.makeActivity()
        
        activity.userInfo?[Self.ActiveTabKey] = self.currentTab.rawValue
        
        return activity
    }
    
    public static func restore(from userInfo: [AnyHashable: Any]?) -> RestorationInfo? {
        guard let raw = userInfo?[Self.ActiveTabKey] as? NavigationBarButtonViewModel.RawValue,
              let tab = NavigationBarButtonViewModel(rawValue: raw) else
        {
            return nil
        }
        return .init(activeTab: tab)
    }
}
