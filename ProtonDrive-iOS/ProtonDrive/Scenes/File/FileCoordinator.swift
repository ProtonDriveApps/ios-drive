// Copyright (c) 2024 Proton AG
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

import Combine
import Foundation
import PDCore
import UIKit
import PDLocalization

final class FileCoordinator {
    private var dismissHandler: () -> Void
    private var fileEventCancellable: Cancellable?
    private var presentingFileModel: FileModel?
    private var tower: Tower
    private weak var rootViewController: UIViewController?
    private weak var alert: UIAlertController?
    
    init(tower: Tower, rootViewController: UIViewController?, dismissHandler: @escaping () -> Void) {
        self.tower = tower
        self.rootViewController = rootViewController
        self.dismissHandler = dismissHandler
    }
    
    func openFilePreview(file: File, share: Bool) {
        let model = preparePreviewModel(file: file, share: share)
        presentingFileModel = model
        model.decrypt()
        presentDecryptionAlert(title: Localization.general_decrypting, message: nil, cancelAction: model.cancel)
    }
}

// MARK: - Private functions
extension FileCoordinator {
    private func preparePreviewModel(file: File, share: Bool) -> FileModel {
        // this one should not be cached as we do not want to keep cleartext file longer than needed
        let model = FileModel(tower: tower, revision: file.activeRevision)
        fileEventCancellable = model.events
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                switch event {
                case .initial:
                    break
                case .decrypted:
                    self?.presentFilePreview(share: share)
                case .closed:
                    self?.presentingFileModel = nil
                    self?.fileEventCancellable = nil
                    self?.dismissHandler()
                case .error(let description):
                    self?.presentDecryptionFailedAlert(error: description)
                }
            }
        return model
    }
    
    private func presentFilePreview(share: Bool) {
        let preview = PMPreviewController()
        preview.share = share
        preview.delegate = presentingFileModel
        preview.dataSource = presentingFileModel
        dismissAlertController { [weak self] in
            self?.rootViewController?.navigationController?.present(preview, animated: true)
        }
    }
    
    // SwiftUI alert doens't have dismiss completion
    // Can't show alert right after dismiss previous alert
    private func presentDecryptionAlert(title: String, message: String?, cancelAction: @escaping (() -> Void)) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let action = UIAlertAction(title: Localization.general_cancel, style: .default) { _ in
            cancelAction()
        }
        alert.addAction(action)
        rootViewController?.navigationController?.present(alert, animated: true)
        self.alert = alert
    }
    
    private func presentDecryptionFailedAlert(error: String) {
        dismissAlertController { [weak self] in
            self?.presentDecryptionAlert(title: Localization.general_decryption_failed, message: error, cancelAction: {
                self?.presentingFileModel?.cleanup()
            })
        }
    }
    
    private func dismissAlertController(completion: @escaping () -> Void) {
        guard let alert else {
            completion()
            return
        }
        alert.dismiss(animated: true, completion: completion)
    }
}
