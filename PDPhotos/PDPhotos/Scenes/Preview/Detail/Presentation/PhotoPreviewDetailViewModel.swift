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
import PDLocalization

protocol PhotoPreviewDetailViewModelProtocol: ObservableObject {
    var state: PhotoPreviewDetailState? { get }
    var mode: AnyPublisher<PhotosPreviewMode, Never> { get }
    func viewDidLoad()
    func toggleMode()
    func setActive()
    func share()
    func cleanup()
}

enum PhotoPreviewDetailState: Equatable {
    case loading(String)
    case preview(PhotoFullPreview)
    case error(title: String, text: String)
}

struct PhotoPreviewDetailError {
    let message: String
    let button: String
}

final class PhotoPreviewDetailViewModel: PhotoPreviewDetailViewModelProtocol {
    private let thumbnailController: ThumbnailController
    private let modeController: PhotosPreviewModeController
    private let previewController: PhotosPreviewController
    private let detailController: PhotoPreviewDetailController
    private let fullPreviewController: PhotoFullPreviewController
    private let shareController: PhotoPreviewDetailShareController
    private let id: PhotoId
    private let coordinator: PhotoPreviewDetailCoordinator
    private let metadataController: MetadataControllerProtocol
    private var cancellables = Set<AnyCancellable>()
    private var areMetadataFetched = false
    private var isInitialLoadFinished = false
    var mode: AnyPublisher<PhotosPreviewMode, Never> { modeController.mode }
    @Published var state: PhotoPreviewDetailState?

    init(thumbnailController: ThumbnailController, modeController: PhotosPreviewModeController, previewController: PhotosPreviewController, detailController: PhotoPreviewDetailController, fullPreviewController: PhotoFullPreviewController, shareController: PhotoPreviewDetailShareController, id: PhotoId, coordinator: PhotoPreviewDetailCoordinator, metadataController: MetadataControllerProtocol) {
        self.thumbnailController = thumbnailController
        self.modeController = modeController
        self.previewController = previewController
        self.detailController = detailController
        self.fullPreviewController = fullPreviewController
        self.shareController = shareController
        self.id = id
        self.coordinator = coordinator
        self.metadataController = metadataController
        subscribeToUpdates()
    }

    deinit {
        cleanup()
    }

    func viewDidLoad() {
        fetchMetadataIfPossible()
        thumbnailController.load()
        reloadData()
        isInitialLoadFinished = true
    }

    private func fetchMetadataIfPossible() {
        // Metadata of whole photo compound (primary + secondary) are needed before loading file content.
        let ids = previewController.getListing(id: id)?.allIds ?? []
        if !ids.isEmpty {
            metadataController.loadImmediatelly(ids)
        }
        // If ids are empty, the preview controller will notify once they're populated and we will refetch metadata then.
    }

    func toggleMode() {
        modeController.toggle()
    }

    func setActive() {
        previewController.setCurrent(id)
        detailController.execute(with: id)
    }

    func share() {
        guard areMetadataFetched else {
            return
        }
        shareController.openShare()
    }

    private func subscribeToUpdates() {
        thumbnailController.bootstrap()
        thumbnailController.updatePublisher
            .sink { [weak self] _ in
                self?.reloadData()
            }
            .store(in: &cancellables)

        fullPreviewController.updatePublisher
            .sink { [weak self] preview in
                self?.reloadData()
            }
            .store(in: &cancellables)

        fullPreviewController.errorPublisher
            .sink { [weak self] error in
                self?.handlePreviewError(error)
            }
            .store(in: &cancellables)

        metadataController.readyIDs
            .sink { [weak self] readyIds in
                guard let self else { return }
                if readyIds.contains(self.id) {
                    self.handleMetadataUpdate()
                }
            }
            .store(in: &cancellables)

        metadataController.failedIDs
            .sink { [weak self] readyIds in
                guard let self else { return }
                if readyIds.contains(self.id) {
                    self.setGenericError()
                }
            }
            .store(in: &cancellables)

        previewController.updatePublisher
            .sink { [weak self] in
                self?.handlePreviewUpdate()
            }
            .store(in: &cancellables)
    }

    private func handleMetadataUpdate() {
        areMetadataFetched = true
        fullPreviewController.load()
    }

    private func reloadData() {
        let state = makeNewState()
        if self.state != state {
            self.state = state
        }
    }

    private func makeNewState() -> PhotoPreviewDetailState {
        if let fullPreview = fullPreviewController.getPreview() {
            return .preview(fullPreview)
        } else if let thumbnail = thumbnailController.getImage() {
            return .preview(.thumbnail(thumbnail))
        } else {
            return .loading(Localization.general_loading)
        }
    }
    
    func cleanup() {
        fullPreviewController.clear()
        thumbnailController.cancel()
    }

    private func handlePreviewError(_ error: PhotoFullPreviewError) {
        switch error {
        case .noPreviewAvailable:
            setGenericError()
        case .fullPreviewNotAvailable:
            // no-op
            break
        }
    }

    private func handlePreviewUpdate() {
        if isInitialLoadFinished && !areMetadataFetched {
            fetchMetadataIfPossible()
        }
    }

    private func setGenericError() {
        state = .error(
            title: Localization.photo_preview_error_title,
            text: Localization.photo_preview_error_text
        )
    }
}
