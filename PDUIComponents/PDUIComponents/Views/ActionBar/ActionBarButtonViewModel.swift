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
import PDLocalization

#if os(iOS)
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
    case newShare
    case removeMe
    case info
    case toggleFavorite
    case favorite
    case unFavorite
    case more
    case setAsAlbumCover
    case createAlbum
    case shareMultiple
    case save

    // MARK: - Properties
    
    public var icon: Image? {
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
        case .removeMe: return .init("ic_user_cross")
        case .newShare: return IconProvider.userPlus
        case .info: return IconProvider.infoCircle
        case .toggleFavorite: return IconProvider.heart
        case .favorite: return IconProvider.heart
        case .unFavorite: return .init("ic-heart-filled")
        case .more: return IconProvider.threeDotsHorizontal
        case .setAsAlbumCover: return IconProvider.windowImage
        case .createAlbum: return IconProvider.plus
        case .shareMultiple: return IconProvider.arrowUpFromSquare
        case .save: return Image("ic-cloud-arrow-down", bundle: .module)
        }
    }
    
    public var accessibilityIdentifier: String {
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
        case .removeMe: return "ActionBar.Button.RemoveMe"
        case .newShare: return "ActionBar.Button.NewShare"
        case .info: return "ActionBar.Button.info"
        case .toggleFavorite: return "ActionBar.Button.favorite"
        case .favorite: return "ActionBar.button.favorite"
        case .unFavorite: return "ActionBar.button.unFavorite"
        case .more: return "ActionBar.Button.MoreSingle"
        case .setAsAlbumCover: return "ActionBar.Button.setAsAlbumCover"
        case .createAlbum: return "ActionBar.Button.createAlbum"
        case .shareMultiple: return "ActionBar.Button.shareMultiple"
        case .save: return "ActionBar.Button.save"
        }
    }
    
    public var title: String? {
        switch self {
        case .trashMultiple: return Localization.general_remove
        case .deleteMultiple: return Localization.general_delete
        case .restoreMultiple: return Localization.general_restore
        case .createFolder: return "New folder"
        case .cancel: return Localization.general_cancel
        case .offlineAvailableMultiple: return Localization.edit_section_make_available_offline
        case .info: return Localization.file_detail_title
        case .setAsAlbumCover: return Localization.action_set_as_album_cover
        case .createAlbum: return Localization.empty_albums_action
        case .shareNative: return Localization.general_share
        case .shareMultiple: return Localization.general_share
        case .save: return Localization.general_save
        default: return nil
        }
    }

    var showTitle: Bool {
        switch self {
        case .deleteMultiple, .restoreMultiple, .createFolder, .cancel: return true
        default: return false
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
        case .trashMultiple, .cancel, .removeMe, .setAsAlbumCover, .createAlbum, .shareMultiple, .save: return false
        case .deleteMultiple, .restoreMultiple, .createFolder, .moveMultiple, .offlineAvailableMultiple, .share, .newShare, .shareNative, .info, .toggleFavorite, .more, .favorite, .unFavorite: return true
        }
    }

    var isContextMenu: Bool {
        switch self {
        case .more: return true
        default: return false
        }
    }
}

extension ActionBarButtonViewModel: Identifiable {
    public var id: Int { rawValue }
}
#endif
