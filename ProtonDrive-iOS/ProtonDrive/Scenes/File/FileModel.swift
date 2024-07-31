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
    var tower: Tower
    enum Events: Equatable { case initial, decrypted, closed, error(String) }
    
    private var eventsSubject = PassthroughSubject<Events, Never>()

    var events: AnyPublisher<Events, Never>

    private var isCancelled = false
    
    private let revision: Revision?
    private var cleartextUrl: URL?
    
    init(tower: Tower, revision: Revision?) {
        self.tower = tower
        self.revision = revision
        self.events = eventsSubject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
    
    func cancel() {
        self.isCancelled = true
    }
    
    func decrypt() {
        guard self.cleartextUrl == nil, let revision = self.revision else { return }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cleanup),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
        
        self.tower.uiSlot?.performInBackground { moc in
            do {
                let revision = revision.in(moc: moc)
                self.cleartextUrl = try revision.decryptFile(isCancelled: &self.isCancelled)
                DispatchQueue.main.async {
                    self.eventsSubject.send(.decrypted)
                }
            } catch let error where !self.isCancelled {
                DispatchQueue.main.async {
                    self.eventsSubject.send(.error(error.localizedDescription))
                }
            } catch {
                DispatchQueue.main.async {
                    self.cleanup()
                }
            }
        }
    }
    
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        self.cleartextUrl == nil ? 0 : 1
    }
    
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        self.cleartextUrl! as QLPreviewItem
    }
    
    func previewControllerWillDismiss(_ controller: QLPreviewController) {
        self.cleanup()
    }

    func previewController(_ controller: QLPreviewController, editingModeFor previewItem: QLPreviewItem) -> QLPreviewItemEditingMode {
        .disabled
    }

    func previewController(_ controller: QLPreviewController, didSaveEditedCopyOf previewItem: QLPreviewItem, at modifiedContentsURL: URL) {
        guard let revision = revision else { return }
        guard let moc = revision.moc else { return }

        moc.perform {
            do {
                let file = try self.tower.revisionImporter.importNewRevision(from: modifiedContentsURL, into: revision.file)
                self.tower.fileUploader.upload(file, completion: { _ in })
            } catch {
                try? FileManager.default.removeItem(at: modifiedContentsURL)
            }
        }
    }
    
    @objc
    func cleanup() {
        if let url = self.cleartextUrl {
            try? FileManager.default.removeItemIncludingUniqueDirectory(at: url)
            self.cleartextUrl = nil
        }
        self.eventsSubject.send(.closed)
    }
}
