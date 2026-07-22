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

import UIKit
import PDCore
import PDCoreIOS
import PDLocalization

enum PickerError: Error, LocalizedError {
    case importFailures(errors: [Error])
    case unsupportedFileType(fileExtension: String)

    var errorDescription: String? {
        switch self {
        case let .importFailures(errors):
            let file = Localization.file_plural_type_with_num(num: errors.count).lowercased()
            let title = errors.first?.localizedDescription ?? ""
            return Localization.file_pickup_error(files: file, error: title)
        case .unsupportedFileType(let fileExtension):
            return Localization.file_pickup_unsupported(fileExtension: fileExtension)
        }
    }
}

extension FolderModel: PickerDelegate {
    public func picker(didFinishPicking items: [URLResult]) {
        var errors = [Error]()
        for item in items {
            switch item {
            case .success(let content):
                do {
                    try upload(content: content)
                } catch {
                    errors.append(error)
                }
            case .failure(let error):
                errors.append(error)
            }
        }
        if !errors.isEmpty {
            let error = PickerError.importFailures(errors: errors)
            errorSubject.send(error)
        }
    }

    private func upload(content: URLContent) throws {
        let sdkUploader = tower.sdkObjects.fileUploader
        let newFile = try tower.fileImporter.importFile(from: content.url, to: currentFolder, with: nil)
        guard content.size == content.url.fileSize else {
            assert(false, "Failed to create File")
            throw URLConsistencyError.urlSizeMismatch
        }
        Task {
            try await sdkUploader.upload(identifier: newFile.identifier.any())
        }
    }
}

private extension FolderModel {
    var currentFolder: Folder {
        node
    }
}
