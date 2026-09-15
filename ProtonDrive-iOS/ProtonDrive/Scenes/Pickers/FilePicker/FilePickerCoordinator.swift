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
import UniformTypeIdentifiers
import PDCore
import PDCoreIOS
import PDSDKCore
import PhotosUI
import VisionKit

@MainActor
final class FilePickerCoordinator {
    private let parentCoordinator: PickerCoordinator
    private let hasUnlimitedPickerSelection: Bool
    private(set) var scannerNavigation: UINavigationController?
    private var handler: AnyObject?

    init(parentCoordinator: PickerCoordinator, featureFlagsController: FeatureFlagsControllerProtocol) {
        self.parentCoordinator = parentCoordinator
        self.hasUnlimitedPickerSelection = featureFlagsController.hasUnlimitedPickerSelection
    }

    func presentCamera(parentFolder: NodeDTO) {
        let imagePickerController = DriveImagePickerController()
        let handler = CameraPickerHandler(parentFolder: parentFolder, pickerCoordinator: parentCoordinator)
        self.handler = handler
        imagePickerController.delegate = handler
        imagePickerController.mediaTypes = [UTType.image.identifier, UTType.movie.identifier]
        imagePickerController.sourceType = .camera
        imagePickerController.cameraCaptureMode = .photo
        imagePickerController.modalPresentationStyle = .fullScreen
        imagePickerController.showsCameraControls = true
        parentCoordinator.navigationController?.present(imagePickerController, animated: true)
    }

    func presentPhotoLibraryPicker(parentFolder: NodeDTO) {
        let container = makeContainer(picker: makePHPicker(parentFolder: parentFolder))
        parentCoordinator.navigationController?.present(container, animated: true)
    }

    func presentDocumentPicker(parentFolder: NodeDTO) {
        let container = makeContainer(picker: makeDocumentPicker(parentFolder: parentFolder))
        parentCoordinator.navigationController?.present(container, animated: true)
    }

    func presentScanner(parentFolder: NodeDTO) {
        let documentCameraViewController = VNDocumentCameraViewController()
        let scannerNavigation = UINavigationController(rootViewController: documentCameraViewController)
        self.scannerNavigation = scannerNavigation
        scannerNavigation.setNavigationBarHidden(true, animated: false)
        scannerNavigation.modalPresentationStyle = .fullScreen
        let handler = DocumentScannerHandler(
            parentFolder: parentFolder,
            pickerCoordinator: parentCoordinator,
            filePickerCoordinator: self
        )
        self.handler = handler
        documentCameraViewController.delegate = handler
        parentCoordinator.navigationController?.present(scannerNavigation, animated: true)
    }

    func showNamingScreen(pdfData: Data, parentFolder: NodeDTO) {
        guard let scannerNavigation else { return }

        let vc = makeNamingViewController { [weak self] name in
            do {
                let url = PDFileManager.prepareUrlForFile(named: "\(name).pdf")
                try pdfData.write(to: url)
                guard let size = url.fileSize else {
                    self?.parentCoordinator.picker(
                        didFinishPicking: [.failure(FilePickError.fileSizeUnavailable)],
                        to: parentFolder
                    )
                    return
                }
                let scanResult: [URLResult] = [.success(.init(url, size))]
                self?.parentCoordinator.picker(didFinishPicking: scanResult, to: parentFolder)
            } catch {
                self?.parentCoordinator.picker(didFinishPicking: [.failure(error)], to: parentFolder)
            }
        }
        scannerNavigation.setViewControllers([vc], animated: true)
        scannerNavigation.setNavigationBarHidden(false, animated: false)
    }

    private func makeNamingViewController(onSetName: @escaping (String) -> Void) -> UIViewController {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withYear, .withMonth, .withDay, .withDashSeparatorInDate]
        formatter.timeZone = TimeZone.autoupdatingCurrent
        let name = "Scan_\(formatter.string(from: Date()))"
        let vm = DocumentNameViewModel(
            validator: NameValidations.iosName,
            fullName: name,
            onSetName: onSetName
        )
        vm.onDismiss = { [weak self] in
            self?.parentCoordinator.dismissPicker(completion: nil)
        }
        let formattingViewModel = FormattingFileViewModel(
            initialName: name,
            nameAttributes: EditNodeViewController.nameAttributes,
            extensionAttributes: EditNodeViewController.nameAttributes
        )
        let viewController = EditNodeViewController()
        viewController.viewModel = vm
        viewController.tfViewModel = formattingViewModel
        return viewController
    }

    // Picker is a remote view controller (PhotosUI runs in another process via XPC).
    // Presenting it directly blocks present(_:completion:) until that remote UI is ready (~2s on first launch),
    // so the sheet appears late and already shows photos — no loading spinner.
    // Present a local container here and add the picker as a child to unblock present(_:completion:) for better UX
    private func makeContainer(picker: UIViewController) -> UIViewController {
        let container = UIViewController()

        container.addChild(picker)
        picker.view.frame = container.view.bounds
        picker.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.view.addSubview(picker.view)
        picker.didMove(toParent: container)
        return container
    }

    private func makePHPicker(parentFolder: NodeDTO) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.preferredAssetRepresentationMode = .current
        configuration.selectionLimit = hasUnlimitedPickerSelection ? 250 : 10

        let controller = PHPickerViewController(configuration: configuration)
        let handler = PhotosPickerHandler(
            parentFolder: parentFolder,
            resource: PhotosPickerFactory().makePhotoResource(),
            pickerCoordinator: parentCoordinator
        )
        self.handler = handler
        controller.delegate = handler
        return controller
    }

    private func makeDocumentPicker(parentFolder: NodeDTO) -> UIDocumentPickerViewController {
        let supportedTypes: [UTType] = [.image, .item, .content]
        let documentPickerController = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes, asCopy: true)
        let handler = DocumentPickerHandler(parentFolder: parentFolder, pickerCoordinator: parentCoordinator)
        self.handler = handler
        documentPickerController.delegate = handler
        documentPickerController.allowsMultipleSelection = hasUnlimitedPickerSelection
        return documentPickerController
    }
}
