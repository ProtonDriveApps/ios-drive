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

import Combine
import UIKit
import SwiftUI
import PhotosUI
import PDCore
import PDLocalization
import PDUIComponents
import ProtonCoreUIFoundations

struct PhotoPicker: UIViewControllerRepresentable {
    typealias URLErrorCompletion = (URL?, Error?) -> Void
    typealias Controller = UIDocumentPickerViewController

    @EnvironmentObject var root: RootViewModel
    private weak var delegate: PickerDelegate?
    private let resource: PhotoPickerLoadResource
    private var cancellables = Set<AnyCancellable>()

    init(resource: PhotoPickerLoadResource, delegate: PickerDelegate) {
        self.delegate = delegate
        self.resource = resource
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(resource: resource, parent: self)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        #if SUPPORTS_UNLIMITED_PICKER_SELECTION
            configuration.selectionLimit = 250
        #else
            configuration.selectionLimit = 10
        #endif

        let controller = PHPickerViewController(configuration: configuration)
        controller.delegate = context.coordinator
        controller.modalPresentationStyle = .overFullScreen
        return controller
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) { }

    func close() {
        root.closeCurrentSheet.send()
    }

    func picker(didFinishPicking items: [URLResult]) {
        delegate?.picker(didFinishPicking: items)
        close()
    }

    // MARK: - SwiftUICoordinator
    class Coordinator: PHPickerViewControllerDelegate {
        private let parent: PhotoPicker
        private let resource: PhotoPickerLoadResource
        private var cancellables = Set<AnyCancellable>()
        private var didFinishSelecting = false

        init(resource: PhotoPickerLoadResource, parent: PhotoPicker) {
            self.parent = parent
            self.resource = resource
            resource.resultsPublisher
                .sink { [weak self] results in
                    self?.parent.picker(didFinishPicking: results)
                }
                .store(in: &cancellables)
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard !didFinishSelecting else { return }
            didFinishSelecting = true

            if !results.isEmpty {
                setupOverlay(on: picker)
            }

            resource.set(itemProviders: results.map(\.itemProvider))
        }
        
        private func setupOverlay(on picker: UIViewController) {
            let label = UILabel(Localization.photos_picker_warning, font: nil, textColor: ColorProvider.TextHint)
            label.numberOfLines = 0
            label.textAlignment = .center
            
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
            stack.constrainBySuperviewBounds(padding: 20)
            
            UIView.animate(withDuration: 0.3) {
                blur.alpha = 0.95
            } completion: { _ in
                stack.isHidden = false
            }
        }
    }
}
