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
import PDCore

typealias PhotosPreviewItem = PhotoId
typealias PhotosPreviewViewMode = PhotosPreviewMode

protocol PhotosPreviewViewModelProtocol: ObservableObject {
    var title: String { get }
    var mode: PhotosPreviewViewMode { get }
    func getCurrentItem() -> PhotosPreviewItem
    func getPreviousItem() -> PhotosPreviewItem?
    func getNextItem() -> PhotosPreviewItem?
    func close()
}

final class PhotosPreviewViewModel: PhotosPreviewViewModelProtocol {
    private let controller: PhotosPreviewController
    private let coordinator: PhotosPreviewListCoordinator
    private let modeController: PhotosPreviewModeController
    private let detailController: PhotoPreviewDetailController

    @Published var title: String = ""
    @Published var mode: PhotosPreviewViewMode = .default

    init(controller: PhotosPreviewController, coordinator: PhotosPreviewListCoordinator, modeController: PhotosPreviewModeController, detailController: PhotoPreviewDetailController) {
        self.controller = controller
        self.coordinator = coordinator
        self.modeController = modeController
        self.detailController = detailController
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        modeController.mode
            .assign(to: &$mode)
        detailController.photo
            .map(\.name)
            .assign(to: &$title)
    }

    func getCurrentItem() -> PhotosPreviewItem {
        controller.getCurrent()
    }

    func getPreviousItem() -> PhotosPreviewItem? {
        controller.getPrevious()
    }

    func getNextItem() -> PhotosPreviewItem? {
        controller.getNext()
    }

    func close() {
        coordinator.close()
    }
}
