// Copyright (c) 2023 Proton AG
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

import Combine
import PDCore
import SwiftUI
import PDUIComponents
import ProtonCoreUIFoundations
import PDLocalization

struct MoreSectionViewModel {
    let file: File

    var items: [MoreSectionItem] {
        if canExportFile { return [.shareIn, .download] }
        return []
    }
}

extension MoreSectionViewModel {
    private var canExportFile: Bool {
        if file.activeRevision != nil, file.isDownloadable {
            return true
        } else {
            return false
        }
    }
}

extension MoreSectionViewModel {
    enum MoreSectionItem: String, SectionItemDisplayable {
        case shareIn
        case download

        var text: String {
            switch self {
            case .shareIn: return Localization.more_action_open_in
            case .download: return Localization.more_action_download
            }
        }

        var icon: Image {
            switch self {
            case .shareIn: return IconProvider.arrowOutFromRectangle
            case .download: return IconProvider.arrowDownLine
            }
        }

        var identifier: String {
            "MoreSectionItem.\(self.rawValue)"
        }
    }
}

extension MoreSectionViewModel.MoreSectionItem: Identifiable, MirrorableEnum {
    var id: String { mirror.label }
}
