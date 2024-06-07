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
import ProtonCoreUIFoundations

public enum ActionBarButtonViewModel: Int {
    case createFolder
    case cancel
    case deleteMultiple
    case trashMultiple
    case restoreMultiple
    case moveMultiple
    case offlineAvailableMultiple
    case share
    case shareNative
    
    // MARK: - Properties
    
    var icon: Image? {
        switch self {
        case .trashMultiple: return IconProvider.trash
        case .moveMultiple: return IconProvider.folderArrowIn
        case .offlineAvailableMultiple: return IconProvider.arrowDownCircle
        case .createFolder: return nil
        case .restoreMultiple: return nil
        case .cancel: return nil
        case .deleteMultiple: return nil
        case .share: return IconProvider.link
        case .shareNative: return IconProvider.arrowUpFromSquare
        }
    }
    
    var accessibilityIdentifier: String {
        switch self {
        case .createFolder: return "ActionBar.Button.CreateFolder"
        case .cancel: return "ActionBar.Button.Cancel"
        case .trashMultiple: return "ActionBar.Button.TrashMultiple"
        case .restoreMultiple: return "ActionBar.Button.RestoreMultiple"
        case .moveMultiple: return "ActionBar.Button.MoveMultiple"
        case .offlineAvailableMultiple: return "ActionBar.Button.OfflineAvailableMultiple"
        case .deleteMultiple: return "ActionBar.Button.DeleteMultiple"
        case .share: return "ActionBar.Button.Share"
        case .shareNative: return "ActionBar.Button.ShareNative"
        }
    }
    
    var title: String? {
        switch self {
        case .trashMultiple: return nil
        case .deleteMultiple: return "Delete"
        case .restoreMultiple: return "Restore"
        case .createFolder: return "New folder"
        case .cancel: return "Cancel"
        default: return nil
        }
    }
    
    /// Highlighted buttons always have selection indicator
    var isAutoHighlighted: Bool {
        false
    }
    
    /// Inverted icons have black glyph on white background
    var isInverted: Bool {
        true
    }

    var isBold: Bool {
        switch self {
        case .trashMultiple, .cancel: return false
        case .deleteMultiple, .restoreMultiple, .createFolder, .moveMultiple, .offlineAvailableMultiple, .share, .shareNative: return true
        }
    }
}

extension ActionBarButtonViewModel: Identifiable {
    public var id: Int { rawValue }
}
