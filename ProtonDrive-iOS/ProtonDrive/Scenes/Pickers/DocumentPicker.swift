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
import UIKit
import PDCore
import UniformTypeIdentifiers
import PDUIComponents // Not used but if removed I get compilation errors in SettingsAssembler: No such module 'PMSettings'

struct DocumentPicker: UIViewControllerRepresentable {
    typealias Controller = UIDocumentPickerViewController

    @EnvironmentObject var root: RootViewModel
    private weak var delegate: PickerDelegate?

    init(delegate: PickerDelegate) {
        self.delegate = delegate
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> Controller {
        let supportedTypes: [UTType] = [.image, .item, .content]
        let documentPickerController = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes, asCopy: true)
        documentPickerController.delegate = context.coordinator
        #if SUPPORTS_UNLIMITED_PICKER_SELECTION
            documentPickerController.allowsMultipleSelection = true
        #else
            documentPickerController.allowsMultipleSelection = false
        #endif
        return documentPickerController
    }

    func updateUIViewController(_ uiViewController: Controller, context: Context) {}

    func close() {
        root.closeCurrentSheet.send()
    }

    func picker(didFinishPicking items: [URLResult]) {
        delegate?.picker(didFinishPicking: items)
        close()
    }

    // MARK: - Coordinator
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker

        init(parent: DocumentPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: Controller, didPickDocumentsAt urls: [URL]) {
            DispatchQueue.global(qos: .default).async {
                self.processFiles(at: urls)
            }
        }

        func documentPickerWasCancelled(_ controller: Controller) {
            parent.close()
        }

        private func processFiles(at urls: [URL]) {

            let coordinator: NSFileCoordinator = NSFileCoordinator(filePresenter: nil)
            var error: NSError?
            var fileResults: [URLResult] = []
            let group = DispatchGroup()

            for urlFromPicker in urls {
                group.enter()

                if let size = urlFromPicker.fileSize {
                    coordinator.coordinate(readingItemAt: urlFromPicker, options: [], error: &error) { _ in
                        do {
                            let copyUrl = PDFileManager.prepareUrlForFile(named: urlFromPicker.lastPathComponent)
                            try FileManager.default.copyItem(at: urlFromPicker, to: copyUrl)
                            let item = URLContent(copyUrl, size)
                            fileResults.append(.success(item))
                        } catch {
                            fileResults.append(.failure(error))
                        }
                        group.leave()
                    }
                } else {
                    fileResults.append(.failure(URLConsistencyError.noURLSize))
                }
            }

            group.notify(queue: DispatchQueue.main) { [weak self] in
                self?.parent.picker(didFinishPicking: fileResults)
            }
        }
    }
}
