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

import Foundation
import PDLocalization
import ProtonCoreUIFoundations
import UIKit

// MARK: - Album detail page more action sheet
extension ActionSheet {
    static func presentAlbumMoreActionSheet(
        on viewController: UIViewController,
        currentSort: PhotoSort,
        tapSort: @escaping (PhotoSort) -> Void,
        tapRename: @escaping () -> Void,
        tapDeleteAlbum: @escaping () -> Void
    ) {
        var sheet: PMActionSheet!
        let items: [PMActionSheetItem] = [
//            .init(style: .default(InternalIcon.listArrowDown, Localization.action_sort), handler: { _ in
//                sheet.dismiss(animated: false)
//                sheet = nil
//                presentSortSheet(on: viewController, currentSort: currentSort, tapSort: tapSort)
//            }),
            .init(style: .default(IconProvider.pencil, Localization.action_rename_album), handler: { _ in
                tapRename()
                sheet.dismiss(animated: false)
                sheet = nil
            }),
            makeDeleteAlbumItem(
                title: Localization.action_delete_album,
                handler: { _ in
                    tapDeleteAlbum()
                    sheet.dismiss(animated: true)
                    sheet = nil
                }
            )
        ]
        let group = PMActionSheetItemGroup(items: items, style: .clickable)
        sheet = PMActionSheet(headerView: nil, itemGroups: [group])
        sheet.presentAt(viewController, hasTopConstant: false, animated: true)
    }

    private static func makeDeleteAlbumItem(title: String, handler: @escaping (PMActionSheetItem) -> Void) -> PMActionSheetItem {
        let icComponent = PMActionSheetIconComponent(
            icon: IconProvider.trash,
            iconColor: ColorProvider.NotificationError,
            edge: [nil, nil, nil, 16]
        )
        let textComponent = PMActionSheetTextComponent(
            text: .left(title),
            textColor: ColorProvider.NotificationError,
            edge: [nil, 16, nil, 12]
        )
        return .init(components: [icComponent, textComponent], hasSeparator: false, handler: handler)
    }

    static func presentAlbumMoreActionSheetForGuest(
        on viewController: UIViewController,
        currentSort: PhotoSort,
        tapSort: @escaping (PhotoSort) -> Void,
        tapLeaveAlbum: @escaping () -> Void
    ) {
        var sheet: PMActionSheet!
        let items: [PMActionSheetItem] = [
//            .init(style: .default(InternalIcon.listArrowDown, Localization.action_sort), handler: { _ in
//                sheet.dismiss(animated: false)
//                sheet = nil
//                presentSortSheet(on: viewController, currentSort: currentSort, tapSort: tapSort)
//            }),
            makeDeleteAlbumItem(
                title: Localization.action_leave_album,
                handler: { _ in
                    tapLeaveAlbum()
                    sheet.dismiss(animated: true)
                    sheet = nil
                }
            )
        ]
        let group = PMActionSheetItemGroup(items: items, style: .clickable)
        sheet = PMActionSheet(headerView: nil, itemGroups: [group])
        sheet.presentAt(viewController, hasTopConstant: false, animated: true)
    }

    private static func presentSortSheet(
        on viewController: UIViewController,
        currentSort: PhotoSort,
        tapSort: @escaping (PhotoSort) -> Void
    ) {
        var sheet: PMActionSheet!
        let items: [PMActionSheetItem] = [
            .init(
                style: .text(Localization.sort_oldest_first),
                markType: currentSort == .oldestFirst ? .checkMark : .none,
                handler: { _ in
                    tapSort(.oldestFirst)
                    sheet.dismiss(animated: false)
                    sheet = nil
                }
            ),
            .init(
                style: .text(Localization.sort_newest_first),
                markType: currentSort == .newestFirst ? .checkMark : .none,
                handler: { _ in
                    tapSort(.newestFirst)
                    sheet.dismiss(animated: false)
                    sheet = nil
                }
            ),
            .init(
                style: .text(Localization.sort_recently_added),
                markType: currentSort == .recentlyAdded ? .checkMark : .none,
                handler: { _ in
                    tapSort(.recentlyAdded)
                    sheet.dismiss(animated: false)
                    sheet = nil
                }
            )
        ]
        let group = PMActionSheetItemGroup(items: items, style: .singleSelection)
        sheet = PMActionSheet(headerView: nil, itemGroups: [group])
        sheet.presentAt(viewController, hasTopConstant: false, animated: true)
    }
}
