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

import SwiftUI
import PDCore
import PDUIComponents
import ProtonCoreUIFoundations
import PDLocalization

final class UploadManagementMenuViewModel {
    let node: Node
    let model: UploadsListing

    init(node: Node, model: UploadsListing) {
        self.node = node
        self.model = model
    }

    var items: [UploadManagementItem] {
        [pause, .remove].compactMap { $0 }
    }

    var pause: UploadManagementItem? {
        node.state == .uploading ? .pause : nil
    }

    enum UploadManagementItem: SectionItemDisplayable {

        case pause
        case remove

        var text: String {
            let name: String
            switch self {
            case .pause: name = Localization.general_pause
            case .remove: name = Localization.general_remove
            }
            return name
        }

        var identifier: String {
            return "UploadManagementItem.\(text.lowercased())"
        }

        var icon: Image {
            let name: Image
            switch self {
            case .pause: name = IconProvider.pause
            case .remove: name = IconProvider.cross
            }
            return name
        }
    }
}

extension UploadManagementMenuViewModel.UploadManagementItem: Identifiable, MirrorableEnum {
    var id: String { mirror.label }
}
