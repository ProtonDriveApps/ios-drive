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
import Combine
import QuickLook

class FileModel: NSObject, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
    // The life of the cleartext URL is tied to the life of the repository, please keep it alive as long as needed
    private let repository: FilePreviewRepository

    init(repository: FilePreviewRepository) {
        self.repository = repository
    }

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        1
    }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        repository.getURL() as QLPreviewItem
    }

    func previewControllerWillDismiss(_ controller: QLPreviewController) {
    }

    func previewController(_ controller: QLPreviewController, editingModeFor previewItem: QLPreviewItem) -> QLPreviewItemEditingMode {
        .disabled
    }

    func previewController(_ controller: QLPreviewController, didSaveEditedCopyOf previewItem: QLPreviewItem, at modifiedContentsURL: URL) {

    }
}

extension URL {
    static var blank: URL {
        URL(string: "file:///dev/null")!
    }
}
