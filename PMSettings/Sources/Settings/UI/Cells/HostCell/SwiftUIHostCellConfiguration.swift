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

import SwiftUI
import UIKit

class SwiftUIHostCellConfiguration<Content: View>: PMCellSuplier {
    private let content: Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content()
    }

    func cell(at indexPath: IndexPath, for tableView: UITableView, in parent: UIViewController) -> UITableViewCell {
        let identifier = "SwiftUIHostCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier) as? SwiftUIHostCell<Content> ?? SwiftUIHostCell<Content>(style: .default, reuseIdentifier: identifier)
        cell.configure(with: content, parent: parent)
        return cell
    }
}
