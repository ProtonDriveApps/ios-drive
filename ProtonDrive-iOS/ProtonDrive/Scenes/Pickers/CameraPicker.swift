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
import PDUIComponents
import CoreServices
import AVFoundation
import PDLocalization

struct CameraPicker: UIViewControllerRepresentable {
    typealias Controller = UIImagePickerController

    @EnvironmentObject var root: RootViewModel
    private weak var delegate: PickerDelegate?

    init(delegate: PickerDelegate) {
        self.delegate = delegate
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIViewController(context: Context) -> Controller {
        let imagePickerController = DriveImagePickerController()
        imagePickerController.delegate = context.coordinator
        imagePickerController.mediaTypes = [UTType.image.identifier, UTType.movie.identifier]
        imagePickerController.sourceType = .camera
        imagePickerController.cameraCaptureMode = .photo
        imagePickerController.modalPresentationStyle = .fullScreen
        imagePickerController.showsCameraControls = true
        return imagePickerController
    }
    
    func updateUIViewController(_ uiViewController: Controller, context: Context) {}

    func close() {
        root.closeCurrentSheet.send()
    }

    func picker(didFinishPicking item: URLResult) {
        delegate?.picker(didFinishPicking: [item])
        close()
    }

    // MARK: - Coordinator
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        typealias Info = [UIImagePickerController.InfoKey: Any]

        private let parent: CameraPicker

        init(parent: CameraPicker) {
            self.parent = parent
        }

        func navigationControllerSupportedInterfaceOrientations(_ navigationController: UINavigationController) -> UIInterfaceOrientationMask {
            UIDevice.current.userInterfaceIdiom == .phone ? .portrait : .all
        }

        func imagePickerController(_ picker: Controller, didFinishPickingMediaWithInfo info: Info) {
            guard let urlFromPicker = getPhotoURL(from: info) ?? getVideoURL(from: info) else {
                parent.picker(didFinishPicking: .failure(Errors.failedToImportImage))
                return
            }

            do {
                let size = try urlFromPicker.getFileSize()
                let copyUrl = PDFileManager.prepareUrlForFile(named: urlFromPicker.lastPathComponent)
                try FileManager.default.moveItem(at: urlFromPicker, to: copyUrl)
                let content = URLContent(copyUrl, size)
                parent.picker(didFinishPicking: .success(content))
            } catch {
                parent.picker(didFinishPicking: .failure(error))
            }
        }

        func imagePickerControllerDidCancel(_ picker: Controller) {
            parent.close()
        }

        private func getVideoURL(from info: Info) -> URL? {
            return info[.mediaURL] as? URL
        }

        private func getPhotoURL(from info: Info) -> URL? {
            guard let image = info[.originalImage] as? UIImage, let data = image.jpegData(compressionQuality: 1.0) else {
                return nil
            }

            let copyUrl = PDFileManager.prepareUrlForFile(named: UUID().uuidString + ".jpeg")
            try? data.write(to: copyUrl)

            return copyUrl
        }

        enum Errors: Error {
            case failedToImportImage
        }
    }
}
