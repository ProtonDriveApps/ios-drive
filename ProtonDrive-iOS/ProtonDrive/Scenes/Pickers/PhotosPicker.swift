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

import UIKit
import SwiftUI
import PhotosUI
import PDCore
import PDUIComponents
import ProtonCore_UIFoundations

struct PhotoPicker: UIViewControllerRepresentable {
    typealias Controller = UIDocumentPickerViewController

    @EnvironmentObject var root: RootViewModel
    private weak var delegate: PickerDelegate?

    init(delegate: PickerDelegate) {
        self.delegate = delegate
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.selectionLimit = 10

        let controller = PHPickerViewController(configuration: configuration)
        controller.delegate = context.coordinator
        controller.modalPresentationStyle = .overFullScreen
        return controller
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) { }

    func close() {
        root.closeCurrentSheet.send()
    }

    func picker(didFinishPicking items: [Result<URL, Error>]) {
        delegate?.picker(didFinishPicking: items)
        close()
    }

    // MARK: - SwiftUICoordinator
    class Coordinator: PHPickerViewControllerDelegate {
        private let parent: PhotoPicker
        private var didFinishSelecting = false

        init(_ parent: PhotoPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard !didFinishSelecting else { return }
            didFinishSelecting = true

            if !results.isEmpty {
                setupOverlay(on: picker)
            }
            
            DispatchQueue.global(qos: .default).async {
                self.processFiles(for: results)
            }
        }
        
        private func setupOverlay(on picker: UIViewController) {
            let label = UILabel("Preparing upload", font: nil, textColor: ColorProvider.TextHint)
            
            let activity = UIActivityIndicatorView(style: .large)
            activity.color = ColorProvider.BrandNorm
            activity.startAnimating()
            
            let stack = UIStackView(arrangedSubviews: [activity, label])
            stack.axis = .vertical
            stack.alignment = .center
            stack.isHidden = true
            
            let blur = UIVisualEffectView.blurred
            blur.alpha = 0.0
            
            picker.view.addSubview(blur)
            blur.fillSuperview()
            blur.contentView.addSubview(stack)
            stack.centerInSuperview()
            
            UIView.animate(withDuration: 0.3) {
                blur.alpha = 0.95
            } completion: { _ in
                stack.isHidden = false
            }
        }

        private func processFiles(for results: [PHPickerResult]) {
            var fileResults: [Result<URL, Error>] = []
            let group = DispatchGroup()

            for itemProvider in results.map(\.itemProvider) {
                guard let typeIdentifier = itemProvider.registeredTypeIdentifiers.first else  {
                    fileResults.append(.failure(Errors.noRegisteredTypeIdentifier))
                    continue
                }

                group.enter()

                let onCompletion: (URL?, Error?) -> Void = { url, error in
                    switch (url, error) {
                    case let (url?, nil):
                        do {
                            let copyURL = PDFileManager.prepareUrlForFile(named: url.lastPathComponent)
                            try FileManager.default.moveItem(at: url, to: copyURL)
                            fileResults.append(.success(copyURL))
                        } catch {
                            fileResults.append(.failure(error))
                        }
                    case let (nil, error?):
                        fileResults.append(.failure(error))
                    default:
                        fileResults.append(.failure(Errors.invalidState))
                    }
                    group.leave()
                }

                if UTI(value: typeIdentifier).isLiveAsset {
                    itemProvider.loadObject(ofClass: PHLivePhoto.self) { livePhoto, error in
                        guard let livePhoto = livePhoto as? PHLivePhoto,
                              let resource = PHAssetResource.assetResources(for: livePhoto).first(where: { $0.type == .photo }) else {
                            return onCompletion(nil, Errors.invalidLivePhoto)
                        }

                        let copyURL = PDFileManager.prepareUrlForFile(named: resource.originalFilename)

                        PHAssetResourceManager.default().writeData(for: resource, toFile: copyURL, options: nil) { error in
                            if let error = error {
                                onCompletion(nil, error)
                            } else {
                                onCompletion(copyURL, nil)
                            }
                        }
                    }

                } else {
                    itemProvider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, error in
                        onCompletion(url, error)
                    }
                }
            }

            group.notify(queue: DispatchQueue.main) { [weak self] in
                self?.parent.picker(didFinishPicking: fileResults)
            }
        }

        enum Errors: Error {
            case noRegisteredTypeIdentifier
            case invalidState
            case invalidLivePhoto
        }
    }
}

private extension UTI {
    var isLiveAsset: Bool {
        return isLivePhoto || value == "com.apple.live-photo-bundle"
    }
}
