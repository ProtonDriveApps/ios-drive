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

import Foundation

public enum NavigationBarButtonViewModel: Int {
    case files = 0
    case recent
    case favorites
    case sharing
    case automatic
    
    var iconName: String {
        switch self {
        case .files: return "navi-ic-folder"
        case .recent: return "navi-ic-clock"
        case .favorites: return "navi-ic-star"
        case .sharing: return "navi-ic-link"
        case .automatic: return "question-circle"
        }
    }
    
    var selectedIconName: String {
        switch self {
        case .files: return "navi-ic-folder-filled"
        case .recent: return "navi-ic-clock-filled"
        case .favorites: return "navi-ic-star-filled"
        case .sharing: return "navi-ic-link-filled"
        case .automatic: return "question-circle"
        }
    }
    
    var accessibilityIdentifier: String {
        switch self {
        case .files: return "NavigationBar.Button.Files"
        case .recent: return "NavigationBar.Button.Recent"
        case .favorites: return "NavigationBar.Button.Favorites"
        case .sharing: return "NavigationBar.Button.Sharing"
        case .automatic: return "NavigationBar.Button.Placeholder"
        }
    }
    
    var title: String? {
        switch self {
        case .files: return "Files"
        case .recent: return "Activity"
        case .favorites: return "Starred"
        case .sharing: return "Links"
        case .automatic: return nil
        }
    }
}

extension NavigationBarButtonViewModel: Identifiable {
    public var id: Int { rawValue }
}
