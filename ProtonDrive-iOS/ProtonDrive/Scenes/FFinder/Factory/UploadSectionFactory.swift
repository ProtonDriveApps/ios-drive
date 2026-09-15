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
import PDCoreIOS
import PDSDKCore
import struct PDUIComponents.ContextMenuItem
import struct PDUIComponents.ContextMenuItemGroup
import UIKit

@MainActor
protocol UploadSectionActionHandler: AnyObject {
    func handle(action: UploadSectionItem)
}

/// Factory for the `+` button menu
/// including the available menu items and their corresponding actions
@MainActor
struct UploadSectionFactory {
    private let featureFlagsController: FeatureFlagsControllerProtocol
    private let isSourceTypeAvailable: (UIImagePickerController.SourceType) -> Bool
    private let node: NodeDTO
    private weak var handler: UploadSectionActionHandler?

    init(
        featureFlagsController: FeatureFlagsControllerProtocol,
        isSourceTypeAvailable: @escaping (UIImagePickerController.SourceType) -> Bool,
        node: NodeDTO,
        handler: UploadSectionActionHandler?
    ) {
        self.featureFlagsController = featureFlagsController
        self.isSourceTypeAvailable = isSourceTypeAvailable
        self.node = node
        self.handler = handler
    }

    @MainActor
    func make() -> [ContextMenuItemGroup] {
        guard node.permissions != .view else { return [] }
        let firstSection = [uploadPhoto, takePhoto, importFile].compactMap { $0 }
        let secondSection = [createFolder, createDocument, createSheet, scanDocument].compactMap { $0 }
        return [makeItemGroup(items: firstSection), makeItemGroup(items: secondSection)]
    }

    private func makeItemGroup(items: [ContextMenuItem]) -> ContextMenuItemGroup {
        ContextMenuItemGroup(id: "uploadSection\(items[0].id)", items: items)
    }
}

extension UploadSectionFactory {
    private var uploadPhoto: ContextMenuItem? {
        guard isSourceTypeAvailable(.photoLibrary) else { return nil }
        return ContextMenuItem(sectionItem: UploadSectionItem.uploadPhoto) {
            self.handler?.handle(action: .uploadPhoto)
        }
    }

    private var takePhoto: ContextMenuItem? {
        guard isSourceTypeAvailable(.camera) else { return nil }
        return ContextMenuItem(sectionItem: UploadSectionItem.takePhoto) {
            self.handler?.handle(action: .takePhoto)
        }
    }

    private var importFile: ContextMenuItem {
        ContextMenuItem(sectionItem: UploadSectionItem.importFile) {
            self.handler?.handle(action: .importFile)
        }
    }

    private var createFolder: ContextMenuItem {
        ContextMenuItem(sectionItem: UploadSectionItem.createFolder) {
            self.handler?.handle(action: .createFolder)
        }
    }

    private var createDocument: ContextMenuItem {
        ContextMenuItem(sectionItem: UploadSectionItem.createDocument) {
            self.handler?.handle(action: .createDocument)
        }
    }

    private var createSheet: ContextMenuItem? {
        guard featureFlagsController.hasProtonSheetCreation else { return nil }
        return ContextMenuItem(sectionItem: UploadSectionItem.createSheet) {
            self.handler?.handle(action: .createSheet)
        }
    }

    private var scanDocument: ContextMenuItem {
        ContextMenuItem(sectionItem: UploadSectionItem.scanDocument) {
            self.handler?.handle(action: .scanDocument)
        }
    }
}
