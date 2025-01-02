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

import PDCore
import ProtonCoreUIFoundations
import PDUIComponents
import UIKit

extension UploadManagementMenuViewModel {

    func uploadManagementSection(file: File) -> ContextMenuItemGroup {
        let items = self.items.map { item in
            uploadManagementRows(for: item, file: file)
        }
        return ContextMenuItemGroup(id: "uploadManagementSection", items: items)
    }

    private func uploadManagementRows(for type: UploadManagementItem, file: File) -> ContextMenuItem {
        switch type {
        case .pause: return pause(type, file: file, model: model)
        case .remove: return remove(type, file: file, model: model)
        }
    }

    private func pause(_ type: UploadManagementItem, file: File, model: UploadsListing) -> ContextMenuItem {
        ContextMenuItem(
            sectionItem: type,
            handler: { model.pauseUpload(file: file) }
        )
    }

    private func remove(_ type: UploadManagementItem, file: File, model: UploadsListing) -> ContextMenuItem {
        ContextMenuItem(
            sectionItem: type,
            handler: { model.cancelUpload(file: file) }
        )
    }
    
}
