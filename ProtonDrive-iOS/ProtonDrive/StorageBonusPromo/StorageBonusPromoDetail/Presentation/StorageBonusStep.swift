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
import ProtonCoreUIFoundations
import SwiftUI
import PDLocalization

enum StorageBonusStep: CaseIterable {
    case upload
    case share
    case recovery

    var checklistIdentifier: String {
        switch self {
        case .upload: return "DriveUpload"
        case .share: return "DriveShare"
        case .recovery: return "RecoveryMethod"
        }
    }

    var title: String {
        switch self {
        case .upload: return Localization.checklist_upload_title
        case .share: return Localization.checklist_share_title
        case .recovery: return Localization.checklist_recovery_title
        }
    }

    /// Plain fallback string
    var description: String {
        switch self {
        case .upload:
            return Localization.checklist_upload_description
        case .share:
            return Localization.checklist_share_description
        case .recovery:
            return Localization.checklist_recovery_description
        }
    }
}
