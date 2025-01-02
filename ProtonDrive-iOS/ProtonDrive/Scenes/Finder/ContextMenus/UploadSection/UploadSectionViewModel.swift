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
import SwiftUI
import PDLocalization
import PDUIComponents
import ProtonCoreUIFoundations

final class UploadSectionViewModel {
    let folder: Folder
    let featureFlagsController: FeatureFlagsControllerProtocol

    init(folder: Folder, featureFlagsController: FeatureFlagsControllerProtocol) {
        self.folder = folder
        self.featureFlagsController = featureFlagsController
    }

    var items: [[UploadSectionItem]] {
        guard folder.getNodeRole() != .viewer else {
            return [[]]
        }
        let firstSection = [photo, takePhoto, .importFile].compactMap { $0 }
        let secondSection = [.createFolder, newDocument].compactMap { $0 }
        return [firstSection, secondSection].filter { !$0.isEmpty }
    }

    private var photo: UploadSectionItem? {
        UIImagePickerController.isSourceTypeAvailable(.photoLibrary) ? .uploadPhoto : nil
    }

    private var takePhoto: UploadSectionItem? {
        UIImagePickerController.isSourceTypeAvailable(.camera) ? .takePhoto : nil
    }

    private var newDocument: UploadSectionItem? {
        guard featureFlagsController.hasProtonDocumentCreation else {
            return nil
        }
        return .createDocument
    }

    enum UploadSectionItem: String, CaseIterable, SectionItemDisplayable {
        case importFile
        case uploadPhoto
        case takePhoto
        case createFolder
        case createDocument

        var text: String  {
            let name: String
            switch self {
            case .importFile: name = Localization.import_file_button
            case .uploadPhoto: name = Localization.upload_photo_button
            case .takePhoto: name = Localization.take_new_photo_button
            case .createFolder: name = Localization.create_folder_title
            case .createDocument: name = Localization.create_document_button
            }
            return name
        }

        var icon: Image {
            switch self {
            case .importFile:
                return IconProvider.fileLines
            case .uploadPhoto:
                return IconProvider.image
            case .takePhoto:
                return IconProvider.camera
            case .createFolder:
                return IconProvider.folderPlus
            case .createDocument:
                return Image("ic-brand-proton-docs").renderingMode(.template)
            }
        }

        var identifier: String {
            "UploadSectionItem.\(self.rawValue)"
        }
    }
}

extension UploadSectionViewModel.UploadSectionItem: Identifiable, MirrorableEnum {
    var id: String { mirror.label }
}
