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

protocol TagsMigrationSheetViewModelProtocol {
    var headline: String { get }
    var items: [TagsMigrationSheetViewModel.Item] { get }
    var buttonTitle: String { get }
}

final class TagsMigrationSheetViewModel: TagsMigrationSheetViewModelProtocol {

    let headline: String = Localization.tags_migration_headline
    let items: [Item] = [
        .init(icon: .rotate, desc: Localization.tags_migration_new_filter),
        .init(icon: .lock, desc: Localization.tags_migration_e2e),
        .init(icon: .rocket, desc: Localization.tags_migration_keep_awake)
    ]
    let buttonTitle = Localization.general_got_it
}

extension TagsMigrationSheetViewModel {
    struct Item: Identifiable {
        let icon: Icon
        let desc: String
        var id: String { icon.rawValue }
    }

    enum Icon: String {
        case rotate, lock, rocket
    }
}
