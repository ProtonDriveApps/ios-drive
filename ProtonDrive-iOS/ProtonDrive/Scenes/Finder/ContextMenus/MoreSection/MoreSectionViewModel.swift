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

struct MoreSectionViewModel {
    let file: File

    var items: [MoreSectionItem] {
        [shareIn].compactMap { $0 }
    }
}

extension MoreSectionViewModel {
    private var shareIn: MoreSectionItem? {
        guard file.isDownloadable else {
            return nil
        }
        guard let validBlocks = file.activeRevision?.blocksAreValid(),
        validBlocks else { return nil }
        return .shareIn
    }
}

extension MoreSectionViewModel {
    enum MoreSectionItem: String, SectionItemDisplayable {
        case shareIn

        var text: String {
            let name: String
            switch self {
            case .shareIn: name = "Open in..."
            }
            return name
        }

        var icon: Image {
            let name: Image
            switch self {
            case .shareIn: name = IconProvider.arrowOutFromRectangle
            }
            return name
        }

        var identifier: String {
            "MoreSectionItem.\(self.rawValue)"
        }
    }
}

extension MoreSectionViewModel.MoreSectionItem: Identifiable, MirrorableEnum {
    var id: String { mirror.label }
}
