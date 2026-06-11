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
    var configuration: PhotosRootConfiguration { get }
    var error: PassthroughSubject<Error?, Never> { get }
    var isRefreshing: Bool { get }
    var shouldShowFilterView: Bool { get }
    func refresh()
}

enum PhotosGalleryViewContent: Equatable {
    case loading
    case grid
    case empty
    case placeholder(PhotoTag?)
}

final class PhotosGalleryViewModel: PhotosGalleryViewModelProtocol {
    let configuration: PhotosRootConfiguration
    private let listController: PhotosListControllerProtocol
    private let fetchingController: PhotosListFetchingControllerProtocol
    private let fetchingStatusController: PhotosListFetchingStatusControllerProtocol
    private let errorController: ErrorController
    private let tagsController: GalleryTagsControllerProtocol
    private var cancellables = Set<AnyCancellable>()
    @Published var isRefreshing = false
    @Published var shouldShowFilterView = true

    @Published var content: PhotosGalleryViewContent = .empty
    let error = PassthroughSubject<Error?, Never>()

    init(
        listController: PhotosListControllerProtocol,
        fetchingController: PhotosListFetchingControllerProtocol,
        fetchingStatusController: PhotosListFetchingStatusControllerProtocol,
        errorController: ErrorController,
        configuration: PhotosRootConfiguration,
        tagsController: GalleryTagsControllerProtocol,
        streamConfiguration: PhotoStreamConfiguration
    ) {
        self.listController = listController
        self.fetchingController = fetchingController
        self.fetchingStatusController = fetchingStatusController
        self.errorController = errorController
        self.configuration = configuration
        self.tagsController = tagsController
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        Publishers.CombineLatest3(
            listController.sections.map { $0.isEmpty }.removeDuplicates(),
            listController.isLoading,
            fetchingStatusController.status
        )
        .map { [weak self] isEmpty, isLoadingLocalState, status in
            guard let self else { return .empty }
            return self.map(isEmpty: isEmpty, isLoadingLocalState: isLoadingLocalState, status: status)
        }
        .removeDuplicates()
        .assign(to: &$content)

        if PDPhotosConstants.buildType.isQaOrBelow {
            errorController.errorPublisher
                .sink { [weak self] error in
                    self?.error.send(error)
                }
                .store(in: &cancellables)
        }

        fetchingController.isLoading
            .filter { isLoading in !isLoading }
            .sink { [weak self] _ in
                self?.isRefreshing = false
            }
            .store(in: &cancellables)
    }

    private func map(isEmpty: Bool, isLoadingLocalState: Bool, status: PhotosListFetchingStatus) -> PhotosGalleryViewContent {
        if tagsController.getSelectedTag() == nil {
            shouldShowFilterView = !isEmpty
        }
        switch status {
        case .hasBackedUpPhoto:
            return isLoadingLocalState ? .loading : .grid
        case .withoutBackedUpPhoto:
            return isEmpty ? .placeholder(tagsController.getSelectedTag()) : .grid
        case .undetermined:
            return isEmpty ? .loading : .grid
        case .disconnected, .failure:
            return isEmpty ? .empty : .grid
        }
    }

    func refresh() {
        isRefreshing = true
        fetchingController.reset()
    }
}
