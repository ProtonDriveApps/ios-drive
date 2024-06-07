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

class PasswordChangeDrillDownConfiguration: PMCellSuplier {
    private let viewModel: PasswordChangeSettingsViewModel
    private let viewControllerFactory: () -> (UIViewController)

    init(viewModel: PasswordChangeSettingsViewModel, viewControllerFactory: @escaping () -> (UIViewController)) {
        self.viewModel = viewModel
        self.viewControllerFactory = viewControllerFactory
    }

    func cell(at indexPath: IndexPath, for tableView: UITableView, in parent: UIViewController) -> UITableViewCell {
        let cell: PMDrillDownCell = tableView.dequeueReusableCell()
        let action = { [weak self, weak parent] in
            guard let self = self else {
                return
            }
            let viewController = self.viewControllerFactory()
            self.viewModel.parentViewController = parent
            parent?.navigationController?.pushViewController(viewController, animated: true)
        }
        cell.configureCell(vm: viewModel, action: action, hasSeparator: true)
        return cell
    }
}
