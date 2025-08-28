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
import PDCoreIOS
import ProtonCoreUIFoundations
import UIKit
import PDLocalization
import ProtonCoreFeatureFlags

struct DefaultHomeTabFactory {

    @MainActor
    static func defaultHomeTabRow(tower: Tower, featureFlags: FeatureFlagsControllerProtocol) -> PMCellSuplier {
        let viewModel = DefaultHomeTabSettingViewModel(localSettings: tower.localSettings)
        let config = PMActionableDrillDownConfiguration(viewModel: viewModel) { tableView, indexPath in
            presentDefaultHomeTabSelectionSheet(
                localSettings: tower.localSettings,
                featureFlags: featureFlags,
                tableView: tableView,
                indexPath: indexPath
            )
        }
        return config
    }

    private static func presentDefaultHomeTabSelectionSheet(
        localSettings: LocalSettings,
        featureFlags: FeatureFlagsControllerProtocol,
        tableView: UITableView,
        indexPath: IndexPath
    ) {
        var sheet: PMActionSheet?
        let header = PMActionSheetHeaderView(
            title: Localization.default_home_tab_title,
            leftItem: .right(IconProvider.crossSmall),
            leftItemHandler: {
                sheet?.dismiss(animated: true)
                sheet = nil
            }
        )

        var items: [PMActionSheetItem] = []
        let tabs = availableTabs(localSettings: localSettings, featureFlags: featureFlags)

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
            title: Localization.default_home_tab_setting_sheet_title,
            items: items,
            hasSeparator: false,
            style: .singleSelection
        )
        sheet = PMActionSheet(headerView: header, itemGroups: [group])

        guard let topVC = UIApplication.shared.topViewController() else { return }
        sheet?.presentAt(topVC, hasTopConstant: false, animated: true)
    }

    private static func availableTabs(localSettings: LocalSettings, featureFlags: FeatureFlagsControllerProtocol) -> [TabBarItem] {
        let policy = VisibilityPolicy(responders: [
            PhotosTabVisibilityResponder(localSettings: localSettings, repository: ProtonCoreFeatureFlags.FeatureFlagsRepository.shared),
            ComputersTabVisibilityResponder(featureFlags: featureFlags),
            SharedWithMeTabVisibilityResponder(featureFlags: featureFlags),
            SharedTabVisibilityResponder(featureFlags: featureFlags)
        ])

        var tabs: [TabBarItem] = [.files]

        if policy.shouldShow(.photosTab) {
            tabs.append(.photos)
        }

        if policy.shouldShow(.computersTab) {
            tabs.append(.computers)
        }

        if policy.shouldShow(.sharedWithMeTab) {
            tabs.append(.sharedWithMe)
        } else if policy.shouldShow(.sharedTab) {
            tabs.append(.shared)
        }

        return tabs
    }
}
