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

import Foundation
import PMSettings
import PDCore
import ProtonCoreUIFoundations

struct DefaultHomeTabFactory {

    @MainActor
    static func defaultHomeTabRow(tower: Tower) -> PMCellSuplier {
        let viewModel = DefaultHomeTabSettingViewModel(localSettings: tower.localSettings)
        let config = PMActionableDrillDownConfiguration(viewModel: viewModel) { tableView, indexPath in
            presentDefaultHomeTabSelectionSheet(
                localSettings: tower.localSettings,
                tableView: tableView,
                indexPath: indexPath
            )
        }
        return config
    }
    
    private static func presentDefaultHomeTabSelectionSheet(
        localSettings: LocalSettings,
        tableView: UITableView,
        indexPath: IndexPath
    ) {
        var sheet: PMActionSheet?
        let header = PMActionSheetHeaderView(
            title: "Default home tab",
            leftItem: .right(IconProvider.crossSmall),
            leftItemHandler: {
                sheet?.dismiss(animated: true)
                sheet = nil
            }
        )

        var items: [PMActionSheetItem] = []
        let tabs = availableTab(localSettings: localSettings)

        for option in tabs {
            let item = PMActionSheetItem(
                style: .default(option.icon, option.title),
                userInfo: ["tag": option.tag],
                markType: localSettings.defaultHomeTabTag == option.tag ? .checkMark : .none
            ) { [weak tableView] item in
                guard let tableView, let tag = item.userInfo?["tag"] as? Int else { return }
                localSettings.defaultHomeTabTag = tag
                tableView.reloadRows(at: [indexPath], with: .automatic)
                sheet?.dismiss(animated: true)
                sheet = nil
            }
            items.append(item)
        }
        
        let group = PMActionSheetItemGroup(
            title: "Choose the screen opens by default",
            items: items,
            hasSeparator: false,
            style: .singleSelection
        )
        sheet = PMActionSheet(headerView: header, itemGroups: [group])
        
        guard let topVC = UIApplication.shared.topViewController() else { return }
        sheet?.presentAt(topVC, hasTopConstant: false, animated: true)
    }
    
    private static func availableTab(localSettings: LocalSettings) -> [TabBarItem] {
        [.files, .photos, .shared]
    }
}
