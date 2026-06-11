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
    private let performanceMetricsController: PerformanceMetricsControllerProtocol?
    private let messageHandler: UserMessageHandlerProtocol
    private var didAppear = false

    init(
        repository: FilePreviewRepository,
        performanceMetricsController: PerformanceMetricsControllerProtocol?,
        messageHandler: UserMessageHandlerProtocol
    ) {
        self.repository = repository
        self.performanceMetricsController = performanceMetricsController
        self.messageHandler = messageHandler
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

    func viewDidAppear() {
        guard !didAppear else {
            return
        }
        didAppear = true
        Task {
            let (id, mimeType) = await repository.getFileMetadata()
            performanceMetricsController?.fetchFullContent(id: id, dataSource: .local)
            performanceMetricsController?.reportPreviewToFullContent(id: id, fileType: getFileType(mimeType: mimeType))
        }
    }

    private func getFileType(mimeType: MimeType) -> PerformanceMetric.FileType {
        if mimeType.isImage {
            return .photo
        } else if mimeType.isVideo {
            return .video
        } else if mimeType.isProtonDoc {
            return .protonDoc
        } else if mimeType.isProtonSheet {
            return .protonSheet
        } else {
            return .other
        }
    }
}

extension URL {
    static var blank: URL {
        URL(string: "file:///dev/null")!
    }
}
