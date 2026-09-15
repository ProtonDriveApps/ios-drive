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
import UIKit
import PDCore
import PDCoreIOS
import PDSDKCore

final class DocumentPickerHandler: NSObject, UIDocumentPickerDelegate {
    private let parentFolder: NodeDTO
    private weak var pickerCoordinator: PickerCoordinator?

    init(parentFolder: NodeDTO, pickerCoordinator: PickerCoordinator) {
        self.parentFolder = parentFolder
        self.pickerCoordinator = pickerCoordinator
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        pickerCoordinator?.dismissPicker(completion: nil)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        Task { @MainActor in
            let results = await self.processFiles(at: urls)
            self.pickerCoordinator?.picker(didFinishPicking: results, to: parentFolder)
        }
    }

    private func processFiles(at urls: [URL]) async -> [URLResult] {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        return await withTaskGroup(of: URLResult.self) { group in
            for url in urls {
                group.addTask { await self.processURL(url, coordinator: coordinator) }
            }

            var results: [URLResult] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
    }

    private func processURL(_ url: URL, coordinator: NSFileCoordinator) async -> URLResult {
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
            return .failure(FilePickError.fileSizeUnavailable)
        }

        return await read(url: url, size: size, coordinator: coordinator)
    }

    private func read(url: URL, size: Int, coordinator: NSFileCoordinator) async -> URLResult {
        return await withCheckedContinuation { continuation in
            // Everything runs on main thread 
            var error: NSError?
            var hasResume = false
            coordinator.coordinate(readingItemAt: url, error: &error) { _ in
                defer { hasResume = true }
                do {
                    let copyUrl = PDFileManager.prepareUrlForFile(named: url.lastPathComponent)
                    try FileManager.default.copyItem(at: url, to: copyUrl)
                    let item = URLContent(copyUrl, size)
                    continuation.resume(returning: .success(item))
                } catch {
                    if (error as NSError).isNoSpaceOnDevice {
                        // The original error is too long to read
                        continuation.resume(returning: .failure(SDKUploadErrors.noSpaceOnLocal))
                    } else {
                        continuation.resume(returning: .failure(error))
                    }
                }
            }
            if let error, !hasResume {
                continuation.resume(returning: .failure(error))
            }
        }
    }
}
