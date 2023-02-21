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
import PDUIComponents
import ProtonCore_UIFoundations

final class UploadSectionViewModel {
    let folder: Folder

    init(folder: Folder) {
        self.folder = folder
    }

    var items: [UploadSectionItem] {
        [photo, takePhoto, .createFolder, .importFile].compactMap { $0 }
    }

    var photo: UploadSectionItem? {
        UIImagePickerController.isSourceTypeAvailable(.photoLibrary) ? .uploadPhoto : nil
    }

    var takePhoto: UploadSectionItem? {
        UIImagePickerController.isSourceTypeAvailable(.camera) ? .takePhoto : nil
    }

    enum UploadSectionItem: String, CaseIterable, SectionItemDisplayable {
        case importFile
        case uploadPhoto
        case takePhoto
        case createFolder

        var text: String  {
            let name: String
            switch self {
            case .importFile: name = "Import file"
            case .uploadPhoto: name = "Upload a photo"
            case .takePhoto: name = "Take new photo"
            case .createFolder: name = "Create folder"
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
