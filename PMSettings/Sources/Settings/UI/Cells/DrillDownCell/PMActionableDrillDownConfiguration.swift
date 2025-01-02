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
import UIKit

final public class PMActionableDrillDownConfiguration: PMCellSuplier {
    let viewModel: PMDrillDownCellViewModel
    private var action: ((UITableView, IndexPath) -> Void)
    
    public init(viewModel: PMDrillDownCellViewModel, action: ((UITableView, IndexPath) -> Void)?) {
        self.viewModel = viewModel
        self.action = action ?? { _, _ in }
    }

    public func cell(at indexPath: IndexPath, for tableView: UITableView, in parent: UIViewController) -> UITableViewCell {
        let cell: PMDrillDownCell = tableView.dequeueReusableCell()

        cell.configureCell(
            vm: viewModel,
            action: { [weak self, weak tableView] in
                guard let tableView else { return }
                self?.action(tableView, indexPath)
            },
            hasSeparator: true
        )
        cell.titleLabel.accessibilityIdentifier = viewModel.accessibilityIdentifier
        cell.previewLabel.accessibilityIdentifier = "\(viewModel.accessibilityIdentifier)_preview.\(viewModel.previewAccessibilityIdentifier ?? "unknown")"
        return cell
    }
}
