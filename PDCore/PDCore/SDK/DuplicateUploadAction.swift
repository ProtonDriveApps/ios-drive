// Copyright (c) 2026 Proton AG
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

#if os(iOS)
/// Action for duplicated upload files
public enum DuplicateUploadAction: CaseIterable {
    case replace
    case keepBoth
    case skip

    public var title: String {
        switch self {
        case .replace:
            return Localization.duplication_handler_action_title_replace
        case .keepBoth:
            return Localization.duplication_handler_action_title_keep_both
        case .skip:
            return Localization.duplication_handler_action_title_skip
        }
    }

    public var description: String {
        switch self {
        case .replace:
            return Localization.duplication_handler_action_desc_replace
        case .keepBoth:
            return Localization.duplication_handler_action_desc_keep_both
        case .skip:
            return Localization.duplication_handler_action_desc_skip
        }
    }

    public var accessibilityIdentifier: String {
        switch self {
        case .replace: return "DuplicateUploadAction.replace"
        case .keepBoth: return "DuplicateUploadAction.keepBoth"
        case .skip: return "DuplicateUploadAction.skip"
        }
    }
}
#endif
