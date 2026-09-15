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
import UIKit

final class CameraPickerHandler: NSObject, UIImagePickerControllerDelegate {
    typealias Info = [UIImagePickerController.InfoKey: Any]
    weak var pickerCoordinator: PickerCoordinator?
    private let parentFolder: NodeDTO

    init(parentFolder: NodeDTO, pickerCoordinator: PickerCoordinator? = nil) {
        self.parentFolder = parentFolder
        self.pickerCoordinator = pickerCoordinator
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: Info) {
        do {
            guard let urlFromPicker = try getPhotoURL(from: info) ?? getVideoURL(from: info) else {
                pickerCoordinator?.picker(
                    didFinishPicking: [.failure(FilePickError.failedToImportImage)],
                    to: parentFolder
                )
                return
            }

            let size = try urlFromPicker.getFileSize()
            let copyUrl = PDFileManager.prepareUrlForFile(named: urlFromPicker.lastPathComponent)
            try FileManager.default.moveItem(at: urlFromPicker, to: copyUrl)
            let content = URLContent(copyUrl, size)
            pickerCoordinator?.picker(didFinishPicking: [.success(content)], to: parentFolder)
        } catch {
            pickerCoordinator?.picker(didFinishPicking: [.failure(error)], to: parentFolder)
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        pickerCoordinator?.dismissPicker(completion: nil)
    }

    private func getVideoURL(from info: Info) -> URL? {
        return info[.mediaURL] as? URL
    }

    private func getPhotoURL(from info: Info) throws -> URL? {
        guard
            let image = info[.originalImage] as? UIImage,
            let data = image.jpegData(compressionQuality: 1.0)
        else { return nil }

        let copyUrl = PDFileManager.prepareUrlForFile(named: UUID().uuidString + ".jpeg")
        try data.write(to: copyUrl)

        return copyUrl
    }
}

extension CameraPickerHandler: UINavigationControllerDelegate {
    func navigationControllerSupportedInterfaceOrientations(
        _ navigationController: UINavigationController
    ) -> UIInterfaceOrientationMask {
        UIDevice.current.userInterfaceIdiom == .phone ? .portrait : .all
    }
}
