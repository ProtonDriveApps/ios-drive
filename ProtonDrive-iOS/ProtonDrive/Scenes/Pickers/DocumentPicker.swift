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
import PDCoreIOS
import UniformTypeIdentifiers
import PDUIComponents // Not used but if removed I get compilation errors in SettingsAssembler: No such module 'PMSettings'

struct DocumentPicker: UIViewControllerRepresentable {
    typealias Controller = UIDocumentPickerViewController

    @EnvironmentObject var root: RootViewModel
    private weak var delegate: PickerDelegate?
    private let hasUnlimitedPickerSelection: Bool

    init(delegate: PickerDelegate, featureFlagsController: FeatureFlagsControllerProtocol) {
        self.delegate = delegate
        self.hasUnlimitedPickerSelection = featureFlagsController.hasUnlimitedPickerSelection
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> Controller {
        let supportedTypes: [UTType] = [.image, .item, .content]
        let documentPickerController = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes, asCopy: true)
        documentPickerController.delegate = context.coordinator
        documentPickerController.allowsMultipleSelection = hasUnlimitedPickerSelection
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
            Task {
                let results = await processFiles(at: urls)
                await MainActor.run {
                    parent.picker(didFinishPicking: results)
                }
            }
        }

        func documentPickerWasCancelled(_ controller: Controller) {
            parent.close()
        }

        private func processFiles(at urls: [URL]) async -> [URLResult] {
            await withTaskGroup(of: URLResult.self) { group in
                for url in urls {
                    group.addTask { await self.processURL(url) }
                }
                var results: [URLResult] = []
                for await result in group {
                    results.append(result)
                }
                return results
            }
        }

        private func processURL(_ url: URL) async -> URLResult {
            do {
                let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
                if resourceValues.isDirectory == true {
                    return .failure(PickerError.unsupportedFileType(fileExtension: url.pathExtension))
                }
            } catch {
                Log.error("Read resource value fails", error: error, domain: .fileManager, sendToSentryIfPossible: false)
                return .failure(error)
            }

            guard let size = url.fileSize else {
                return .failure(URLConsistencyError.noURLSize)
            }

            return await copyPickerURL(url, size: size)
        }

        private func copyPickerURL(_ url: URL, size: Int) async -> URLResult {
            await withCheckedContinuation { continuation in
                let coordinator = NSFileCoordinator(filePresenter: nil)
                var coordinationError: NSError?
                var didResume = false
                func resumeOnce(with result: URLResult) {
                    guard !didResume else { return }
                    didResume = true
                    continuation.resume(returning: result)
                }

                coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { _ in
                    do {
                        let copyUrl = PDFileManager.prepareUrlForFile(named: url.lastPathComponent)
                        try FileManager.default.copyItem(at: url, to: copyUrl)
                        resumeOnce(with: .success(URLContent(copyUrl, size)))
                    } catch {
                        if let outOfSpaceError = isOutOfSpaceError(error: error as NSError) {
                            // The original error is too long to read
                            resumeOnce(with: .failure(outOfSpaceError))
                        } else {
                            resumeOnce(with: .failure(error))
                        }
                    }
                }
                if let coordinationError {
                    resumeOnce(with: .failure(coordinationError))
                }
            }
        }

        private func isOutOfSpaceError(error: NSError) -> NSError? {
            let outOfSpaceError = error.underlyingErrors.first { underlyingError in
                let underlyingError = underlyingError as NSError
                guard
                    underlyingError.domain == NSPOSIXErrorDomain,
                    underlyingError.code == 28
                else { return false }
                return true
            }
            return outOfSpaceError as? NSError
        }
    }
}
