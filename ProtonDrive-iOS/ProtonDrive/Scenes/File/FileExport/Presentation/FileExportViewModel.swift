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
import PDCore
import PDCoreIOS
import PDSDKCore
import PDLocalization

final class FileExportViewModel {
    private let interactor: FileExportInteractorProtocol
    private let coordinator: FileExportCoordinatorProtocol
    private let photoLibrary: PhotoLibraryResourceProtocol
    private let messageHandler: UserMessageHandlerProtocol

    init(
        interactor: FileExportInteractorProtocol,
        coordinator: FileExportCoordinatorProtocol,
        photoLibrary: PhotoLibraryResourceProtocol,
        messageHandler: UserMessageHandlerProtocol = UserMessageHandler()
    ) {
        self.interactor = interactor
        self.coordinator = coordinator
        self.photoLibrary = photoLibrary
        self.messageHandler = messageHandler
    }

    func export(files: [NodeDTO], isDownloadDestination: Bool) async {
        guard !files.isEmpty else { return }

        let isDownloading = files.contains { !$0.isDownloaded }
        if isDownloading {
            await coordinator.showProgress { [interactor] in
                files.forEach(interactor.cancel)
            }
        }

        let result = await interactor.downloadAll(files)
        let shouldExportToPhotos = isDownloadDestination && result.containsOnlyMedia

        if isDownloading {
            await coordinator.hideProgress { [weak self] in
                await self?.concludeExport(fileCount: files.count, result: result, shouldExportToPhotos: shouldExportToPhotos)
            }
        } else {
            await concludeExport(fileCount: files.count, result: result, shouldExportToPhotos: shouldExportToPhotos)
        }
    }

    private func concludeExport(fileCount: Int, result: FileDownloadResult, shouldExportToPhotos: Bool) async {
        if shouldExportToPhotos {
            await saveToPhotos(result, fileCount: fileCount)
        } else {
            await presentShareSheet(for: result)
        }
    }

    private func saveToPhotos(_ result: FileDownloadResult, fileCount: Int) async {
        var succeeded = 0
        var failureMessages = result.failures.map { failureMessage(for: $0) }
        for file in result.downloaded {
            do {
                try await photoLibrary.save(file.url, mime: file.mimeType)
                succeeded += 1
            } catch {
                Log.error("Save to photo library failed", error: error, domain: .downloader)
                failureMessages.append(failureMessage(for: error))
            }
        }
        notifySaveResult(fileCount: fileCount, succeeded: succeeded, failureMessages: failureMessages)
    }

    private func presentShareSheet(for result: FileDownloadResult) async {
        guard !result.urls.isEmpty else { return }
        await coordinator.share(result.urls)
    }

    private func notifySaveResult(fileCount: Int, succeeded: Int, failureMessages: [String]) {
        if fileCount == 1 {
            if succeeded == 1 {
                messageHandler.handleSuccess(Localization.download_media_succeeded)
            } else if let message = failureMessages.first {
                messageHandler.handleError(PlainMessageError(message))
            }
            return
        }

        let failed = failureMessages.count
        guard succeeded > 0 || failed > 0 else { return }
        if failed == 0 {
            messageHandler.handleSuccess(Localization.download_multiple_media_succeeded(count: succeeded))
        } else {
            let error = PlainMessageError(Localization.download_multiple_failed(failed: failed, total: succeeded + failed))
            messageHandler.handleError(error)
        }
    }

    private func failureMessage(for error: Error) -> String {
        if let exportError = error as? FileExportError, case .noPhotoLibraryPermission = exportError {
            return Localization.photo_permission_alert_title
        }
        return Localization.download_failed
    }
}
