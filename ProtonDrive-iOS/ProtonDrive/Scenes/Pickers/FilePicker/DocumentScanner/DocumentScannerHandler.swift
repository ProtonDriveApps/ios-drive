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
import PDFKit
import VisionKit

final class DocumentScannerHandler: NSObject, VNDocumentCameraViewControllerDelegate {
    private let parentFolder: NodeDTO
    weak var pickerCoordinator: PickerCoordinator?
    weak var filePickerCoordinator: FilePickerCoordinator?

    init(
        parentFolder: NodeDTO,
        pickerCoordinator: PickerCoordinator,
        filePickerCoordinator: FilePickerCoordinator
    ) {
        self.parentFolder = parentFolder
        self.pickerCoordinator = pickerCoordinator
        self.filePickerCoordinator = filePickerCoordinator
    }

    func documentCameraViewController(
        _ controller: VNDocumentCameraViewController,
        didFinishWith scan: VNDocumentCameraScan
    ) {
        Task { @MainActor in
            guard scan.pageCount > 0 else {
                pickerCoordinator?.picker(didFinishPicking: [.failure(FilePickError.emptyScan)], to: parentFolder)
                return
            }
            let pdfDocument = PDFDocument()

            var documentPage = 0
            for i in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: i)
                guard let pdfPage = PDFPage(image: image) else { continue }
                pdfDocument.insert(pdfPage, at: documentPage)
                documentPage += 1
            }
            if documentPage == 0 {
                // All pdf pages are created failed 
                pickerCoordinator?.picker(
                    didFinishPicking: [.failure(FilePickError.pdfDataGenerationFailed)],
                    to: parentFolder
                )
                return
            }

            guard let documentData = pdfDocument.dataRepresentation() else {
                pickerCoordinator?.picker(
                    didFinishPicking: [.failure(FilePickError.pdfDataGenerationFailed)],
                    to: parentFolder
                )
                return
            }
            filePickerCoordinator?.showNamingScreen(pdfData: documentData, parentFolder: parentFolder)
        }
    }

    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        Task { @MainActor in
            pickerCoordinator?.dismissPicker(completion: nil)
        }
    }

    func documentCameraViewController(
        _ controller: VNDocumentCameraViewController,
        didFailWithError error: any Error
    ) {
        Task { @MainActor in
            pickerCoordinator?.picker(didFinishPicking: [.failure(error)], to: parentFolder)
        }
    }
}
