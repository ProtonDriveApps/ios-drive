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

import PMSettings
import PDLocalization

final class LatestLogsSettingsRowViewModel: PMDrillDownCellViewModel {
    var accessibilityIdentifier: String { "LatestLogsSettingsRow.\(title)" }

    init() { }

    var preview: String? {
        nil
    }

    var title: String { Localization.setting_see_latest_logs }
}

final class BaseDrillDownCellViewModel: PMDrillDownCellViewModel {
    var accessibilityIdentifier: String { "BaseDrillDownCellView.\(title)"}

    private var _title: String
    private var _preview: String?

    init(title: String, preview: String? = nil) {
        self._title = title
        self._preview = preview
    }

    var title: String {
        _title
    }

    var preview: String? {
        _preview
    }
}
