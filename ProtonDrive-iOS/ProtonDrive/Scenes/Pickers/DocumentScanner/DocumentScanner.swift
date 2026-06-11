// Copyright (c) 2025 Proton AG
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
import Foundation
import VisionKit
import PDUIComponents
import PDFKit
import PDCore
import PDCoreIOS

struct DocumentScanner: UIViewControllerRepresentable {
    typealias Controller = UINavigationController

    @EnvironmentObject var root: RootViewModel
    private weak var delegate: PickerDelegate?
    private var nav: UINavigationController?

    init(delegate: PickerDelegate) {
        self.delegate = delegate
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> Controller {
        let documentCameraViewController = VNDocumentCameraViewController()
        documentCameraViewController.delegate = context.coordinator

        let nav = UINavigationController(rootViewController: documentCameraViewController)
        nav.setNavigationBarHidden(true, animated: false)
        context.coordinator.nav = nav
        return nav
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) { }

    func close() {
        root.closeCurrentSheet.send()
    }

    func picker(didFinishPicking items: [URLResult]) {
        delegate?.picker(didFinishPicking: items)
        close()
    }
}

extension DocumentScanner {
    class Coordinator: NSObject {

        private let parent: DocumentScanner
        var nav: UINavigationController?

        init(parent: DocumentScanner) {
            self.parent = parent
        }

        func navigateToNaming(documentData: Data) {
            guard let nav else {
                return
            }
            let editVC = makeNamingVC { [weak self] name in
                do {
                    let url = PDFileManager.prepareUrlForFile(named: "\(name).pdf")
                    try documentData.write(to: url)
                    guard let size = url.fileSize else {
                        self?.parent.picker(didFinishPicking: [.failure(Errors.sizeDoesNotMatch)])
                        return
                    }
                    let scanResult: [URLResult] = [.success(.init(url, size))]
                    self?.parent.picker(didFinishPicking: scanResult)
                } catch {
                    self?.parent.picker(didFinishPicking: [.failure(error)])
                }
            }
            nav.setViewControllers([editVC], animated: true)
            nav.setNavigationBarHidden(false, animated: false)
        }

        private func makeNamingVC(onSetName: @escaping (String) -> Void) -> UIViewController {
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
                self?.parent.close()
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
    }
}

extension DocumentScanner.Coordinator: VNDocumentCameraViewControllerDelegate {
    func documentCameraViewController(
        _ controller: VNDocumentCameraViewController,
        didFinishWith scan: VNDocumentCameraScan
    ) {
        guard scan.pageCount > 0 else {
            parent.picker(didFinishPicking: [.failure(Errors.emptyScan)])
            return
        }
        let pdfDocument = PDFDocument()

        for i in 0..<scan.pageCount {
            let image = scan.imageOfPage(at: i)
            let pdfPage = PDFPage(image: image)
            pdfDocument.insert(pdfPage!, at: i)
        }

        guard let documentData = pdfDocument.dataRepresentation() else {
            parent.picker(didFinishPicking: [.failure(Errors.dataIsNotAvailable)])
            return
        }
        navigateToNaming(documentData: documentData)
    }

    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        parent.close()
    }

    func documentCameraViewController(
        _ controller: VNDocumentCameraViewController,
        didFailWithError error: any Error
    ) {
        parent.picker(didFinishPicking: [.failure(error)])
    }
}

extension DocumentScanner.Coordinator {
    enum Errors: Error {
        case dataIsNotAvailable
        case sizeDoesNotMatch
        case emptyScan
    }
}
