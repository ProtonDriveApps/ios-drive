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

import PDUIComponents
import ProtonCore_UIFoundations
import UIKit
import PDCore

typealias UploadSectionItem = UploadSectionViewModel.UploadSectionItem

extension NodeRowActionMenuViewModel {
    func uploadSection(environment: Environment) -> ContextMenuItemGroup {
        let uploadViewModel = UploadSectionViewModel(folder: node as! Folder)
        let items = uploadViewModel.items.map { item in
            uploadRows(for: item, vm: uploadViewModel, environment: environment)
        }
        return ContextMenuItemGroup(items: items)
    }

    private func uploadRows(for type: UploadSectionItem, vm: UploadSectionViewModel, environment: Environment) -> ContextMenuItem {
        switch type {
        case .uploadPhoto: return uploadPhoto(type, vm: vm, environment: environment)
        case .takePhoto: return takePhoto(type, vm: vm, environment: environment)
        case .createFolder: return createFolder(type, vm: vm, environment: environment)
        case .importFile: return importFile(type, vm: vm, environment: environment)
        }
    }
    
    private func uploadPhoto(_ type: UploadSectionItem, vm: UploadSectionViewModel, environment: Environment) -> ContextMenuItem {
        ContextMenuItem(sectionItem: type, handler: {
            environment.uploadPhoto()
        })
    }

    private func takePhoto(_ type: UploadSectionItem, vm: UploadSectionViewModel, environment: Environment) -> ContextMenuItem {
        ContextMenuItem(sectionItem: type, handler: {
            environment.takePhoto()
        })
    }

    private func createFolder(_ type: UploadSectionItem, vm: UploadSectionViewModel, environment: Environment) -> ContextMenuItem {
        ContextMenuItem(sectionItem: type, handler: {
            environment.createFolder(vm: vm)
        })
    }

    private func importFile(_ type: UploadSectionItem, vm: UploadSectionViewModel, environment: Environment) -> ContextMenuItem {
        ContextMenuItem(sectionItem: type, handler: {
            environment.importFile()
        })
    }

    private func scanToPDF(_ type: UploadSectionItem, vm: UploadSectionViewModel, environment: Environment) -> ContextMenuItem {
        ContextMenuItem(sectionItem: type, handler: {
            environment.onDismiss()
        })
    }

    private func syncPhotoLibrary(_ type: UploadSectionItem, vm: UploadSectionViewModel, environment: Environment) -> ContextMenuItem {
        ContextMenuItem(sectionItem: type, handler: {
            environment.onDismiss()
        })
    }
}
