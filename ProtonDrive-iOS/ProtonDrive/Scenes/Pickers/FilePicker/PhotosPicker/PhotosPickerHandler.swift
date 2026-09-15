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

import Combine
import Foundation
import PDCoreIOS
import PDSDKCore
import PDLocalization
import PhotosUI
import ProtonCoreUIFoundations
import UIKit

final class PhotosPickerHandler: PHPickerViewControllerDelegate {
    private let parentFolder: NodeDTO
    private let resource: PhotoPickerLoadResource
    private var cancellables = Set<AnyCancellable>()
    private var didFinishSelecting = false
    private weak var pickerCoordinator: PickerCoordinator?

    init(
        parentFolder: NodeDTO,
        resource: PhotoPickerLoadResource,
        pickerCoordinator: PickerCoordinator?
    ) {
        self.parentFolder = parentFolder
        self.resource = resource
        self.pickerCoordinator = pickerCoordinator

        resource.resultsPublisher
            .sink { [weak pickerCoordinator] result in
                pickerCoordinator?.picker(didFinishPicking: result, to: parentFolder)
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
