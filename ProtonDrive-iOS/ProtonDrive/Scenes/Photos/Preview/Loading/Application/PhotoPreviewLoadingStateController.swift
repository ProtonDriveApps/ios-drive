// Copyright (c) 2024 Proton AG
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

enum PhotoPreviewLoadingState: Equatable {
    case empty
    case loading
    case error(FileContentError)
}

protocol PhotoPreviewLoadingStateControllerProtocol {
    var state: AnyPublisher<PhotoPreviewLoadingState, Never> { get }
    func startObserving()
}

final class PhotoPreviewLoadingStateController: PhotoPreviewLoadingStateControllerProtocol {
    private let previewController: PhotoFullPreviewController
    private let debounceResource: DebounceResource
    private let subject = CurrentValueSubject<PhotoPreviewLoadingState, Never>(.empty)
    private var isStarted = false
    private var lastError: Error?
    private var cancellables = Set<AnyCancellable>()

    var state: AnyPublisher<PhotoPreviewLoadingState, Never> {
        subject.removeDuplicates().eraseToAnyPublisher()
    }

    init(previewController: PhotoFullPreviewController, debounceResource: DebounceResource) {
        self.previewController = previewController
        self.debounceResource = debounceResource
    }

    func startObserving() {
        guard !isStarted else {
            return
        }

        isStarted = true
        debounceResource.debounce(interval: 2) { [weak self] in
            self?.checkPreviewState()
        }
        previewController.errorPublisher
            .sink { [weak self] error in
                self?.handlePreviewError(error)
            }
            .store(in: &cancellables)
    }

    private func checkPreviewState() {
        handlePreviewUpdate()

        previewController.updatePublisher
            .sink { [weak self] in
                self?.handlePreviewUpdate()
            }
            .store(in: &cancellables)

    }

    private func handlePreviewUpdate() {
        switch previewController.getPreview() {
        case .thumbnail, nil:
            // In case an error was already notified, we keep error state and don't override it when thumbnail is set.
            if lastError == nil {
                subject.send(.loading)
            }
        case .burstPhoto, .livePhoto, .gif, .image, .video:
            subject.send(.empty)
        }
    }

    private func handlePreviewError(_ error: PhotoFullPreviewError) {
        switch error {
        case .noPreviewAvailable:
            // `noPreviewAvailable` leads to full screen error message, so no need to handle it here
            subject.send(.empty)
        case let .fullPreviewNotAvailable(contentError):
            // This is partial error which we should display
            subject.send(.error(contentError))
            lastError = contentError
        }
    }
}
