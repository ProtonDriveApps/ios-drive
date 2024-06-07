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
import Foundation
import PDCore

protocol PhotosGalleryViewModelProtocol: ObservableObject {
    var content: PhotosGalleryViewContent { get }
    var error: PassthroughSubject<Error?, Never> { get }
}

enum PhotosGalleryViewContent {
    case loading
    case grid
    case empty
}

final class PhotosGalleryViewModel: PhotosGalleryViewModelProtocol {
    private let galleryController: PhotosGalleryController
    private let settingsController: PhotoBackupSettingsController
    private let errorController: ErrorController
    private var cancellables = Set<AnyCancellable>()

    @Published var content: PhotosGalleryViewContent = .empty
    let error = PassthroughSubject<Error?, Never>()

    init(galleryController: PhotosGalleryController, settingsController: PhotoBackupSettingsController, errorController: ErrorController) {
        self.galleryController = galleryController
        self.settingsController = settingsController
        self.errorController = errorController
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        Publishers.CombineLatest(
            galleryController.sections.map { $0.isEmpty }.removeDuplicates(),
            settingsController.isEnabled
        )
        .map { isEmpty, isBackupEnabled in
            if !isEmpty {
                return PhotosGalleryViewContent.grid
            } else {
                return isBackupEnabled ? .loading : .empty
            }
        }
        .removeDuplicates()
        .assign(to: &$content)

        #if HAS_QA_FEATURES
        errorController.errorPublisher
            .sink { [weak self] error in
                self?.error.send(error)
            }
            .store(in: &cancellables)
        #endif
    }
}
