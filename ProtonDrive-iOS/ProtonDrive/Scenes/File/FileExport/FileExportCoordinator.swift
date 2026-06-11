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
import UIKit
import PDCoreIOS
import Photos
import PDPhotos
import PDLocalization

final class FileExportCoordinator {
    private let tower: Tower
    private lazy var authorizationResource = LocalPhotoLibraryAuthorizationResource()
    private weak var rootViewController: UIViewController?
    private weak var alert: UIAlertController?
    private var viewModel: FileExportViewModel?
    
    init(tower: Tower, rootViewController: UIViewController?) {
        self.tower = tower
        self.rootViewController = rootViewController
    }
    
    func startExport(file: CoreDataFile, for destination: FinderCoordinator.Destination) async {
        let isDownloadDestination: Bool
        switch destination {
        case .openIn:
            isDownloadDestination = false
        case .downloadToDevice:
            isDownloadDestination = true
        default:
            assertionFailure("Shouldn't have this destination in here")
            return
        }
        do {
            let viewModel = FileExportViewModel(file: file, tower: tower)
            self.viewModel = viewModel
            if try await viewModel.shouldDownload() {
                await MainActor.run { presentAlert() }
                try await viewModel.download()
                await alert?.dismiss(animated: false)
            }
            let path = try viewModel.filePath()
            await handleDownloadSuccess(file: file, filePath: path, isDownloadDestination: isDownloadDestination)
        } catch let error as FileExportError {
            if case .cancelled = error { return }
            UserMessageHandler().handleError(PlainMessageError(error.localizedDescription))
        } catch {
            Log.error("Unexpected file export error", error: error, domain: .downloader)
            UserMessageHandler().handleError(PlainMessageError(error.localizedDescription))
        }
    }

    private func handleDownloadSuccess(file: CoreDataFile, filePath: URL, isDownloadDestination: Bool) async {
        let objectID = file.objectID
        let mime = await self.tower.storage.backgroundContextPool.performInContext { context in
            guard let existingFile: CoreDataFile = try? context.typedObject(with: objectID) else {
                // If the MIME type cannot be determined,
                // fall back to PDF so the content can still be presented via UIActivityViewController.
                // The user can then share it with other apps or save it locally.
                return MimeType.pdf
            }
            let mime = MimeType(value: existingFile.mimeType)
            return mime
        }
        if (mime.isImage || mime.isVideo) && isDownloadDestination {
            await saveMedia(filePath: filePath, mime: mime)
        } else {
            await MainActor.run { [weak self] in self?.presentShareSheet(filePath: filePath) }
        }
    }
}

// MARK: - Media
extension FileExportCoordinator {
    private func saveMedia(filePath: URL, mime: MimeType) async {
        guard await hasPermission() else {
            UserMessageHandler().handleError(PlainMessageError(Localization.photo_permission_alert_title))
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                if mime.isImage {
                    PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: filePath)
                } else if mime.isVideo {
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: filePath)
                }
            }
            UserMessageHandler().handleSuccess(Localization.general_downloaded)
        } catch {
            Log.error("Save media to photo library failed", error: error, domain: .downloader)
            UserMessageHandler().handleError(PlainMessageError(error.localizedDescription))
        }
    }

    private func hasPermission() async -> Bool {
        let permission = await authorizationResource.authorize()
        switch permission {
        case .full:
            return true
        case .restricted, .undetermined:
            return false
        }
    }
}

extension FileExportCoordinator {
    private func presentAlert() {
        let alert = UIAlertController(
            title: "\(Localization.general_downloading)...",
            message: nil,
            preferredStyle: .alert
        )
        alert.addAction(
            UIAlertAction(title: Localization.general_cancel, style: .cancel, handler: { [weak viewModel] _ in
                viewModel?.cancel()
            })
        )
        self.alert = alert
        rootViewController?.present(alert, animated: false)
    }
    
    private func presentShareSheet(filePath: URL) {
        guard let root = rootViewController else { return }
        let vc = UIActivityViewController(activityItems: [filePath], applicationActivities: nil)
        vc.excludedActivityTypes = [.assignToContact, .copyToPasteboard, .markupAsPDF, .print]
        vc.popoverPresentationController?.sourceView = root.view
        root.present(vc, animated: true, completion: nil)
    }
}
