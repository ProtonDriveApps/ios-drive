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
import PDLocalization

protocol PhotoPreviewLoadingStateViewModelProtocol: ObservableObject {
    var content: PhotoPreviewLoadingViewContent { get }
    var alert: PhotoPreviewLoadingAlert? { get set }
    func onAppear()
    func invokeAction()
}

struct PhotoPreviewLoadingAlert: Identifiable {
    var id: String {
        message
    }
    let title: String
    let message: String
    let button: String
}

enum PhotoPreviewLoadingViewContent {
    case empty
    case loading
    case exclamationMark
}

final class PhotoPreviewLoadingStateViewModel: PhotoPreviewLoadingStateViewModelProtocol {
    private let controller: PhotoPreviewLoadingStateControllerProtocol
    private var cancellables = Set<AnyCancellable>()
    private var lastState: PhotoPreviewLoadingState?

    @Published var content: PhotoPreviewLoadingViewContent = .empty
    @Published var alert: PhotoPreviewLoadingAlert?

    init(controller: PhotoPreviewLoadingStateControllerProtocol) {
        self.controller = controller
        subscribeToUpdates()
    }

    func onAppear() {
        controller.startObserving()
    }

    func invokeAction() {
        switch lastState {
        case .empty, nil:
            return
        case .loading:
            setLoadingAlert()
        case .error(let fileContentError):
            setErrorAlert(fileContentError)
        }
    }

    private func setLoadingAlert() {
        alert = PhotoPreviewLoadingAlert(
            title: Localization.photo_preview_loading_title,
            message: Localization.photo_preview_loading_message,
            button: Localization.general_ok
        )
    }

    private func setErrorAlert(_ error: FileContentError) {
        let title: String
        let message: String
        switch error {
        case .failedPhoto:
            title = Localization.photo_preview_error_photo_title
            message = Localization.photo_preview_error_generic
        case .failedVideo:
            title = Localization.photo_preview_error_video_title
            message = Localization.photo_preview_error_generic
        case .unsupportedPhoto:
            title = Localization.photo_preview_error_photo_title
            message = Localization.photo_preview_error_unsupported_format
        case .unsupportedVideo:
            title = Localization.photo_preview_error_video_title
            message = Localization.photo_preview_error_unsupported_format
        }
        alert = PhotoPreviewLoadingAlert(title: title, message: message, button: Localization.general_ok)
    }

    private func subscribeToUpdates() {
        controller.state
            .sink { [weak self] state in
                self?.handleState(state)
            }
            .store(in: &cancellables)
    }

    private func handleState(_ state: PhotoPreviewLoadingState) {
        lastState = state
        switch state {
        case .empty:
            content = .empty
        case .loading:
            content = .loading
        case .error:
            content = .exclamationMark
        }
    }
}
