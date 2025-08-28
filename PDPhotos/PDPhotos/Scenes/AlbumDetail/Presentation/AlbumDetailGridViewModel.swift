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

import Foundation
import Combine

final class AlbumDetailGridViewModel: ObservableObject {
    @Published private(set) var photoViewModel: PhotoListingGridViewModel?
    private let dependencies: Dependencies
    private var cancellables = Set<AnyCancellable>()

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
        photoViewModel = makePhotoViewModel(sections: [])
        subscribeToUpdates()
    }

    var gridViewItems: [PhotoGridViewItem] {
        let items = photoViewModel?.sections.first?.items as? [PhotoGridViewItem]
        return items ?? []
    }

    func makeItemViewModel(from item: PhotoGridViewItem) -> PhotoItemViewModel {
        dependencies.itemViewModelFactory.makeViewModel(for: item)
    }

    func didShowLastPhotoItem() {
        dependencies.photosGridViewModel.didShowLastItem()
    }

    func onEmptyStateAppear() {
        dependencies.photosGridViewModel.didShowLastItem()
    }

    private func subscribeToUpdates() {
        dependencies.photosGridViewModel.sectionsUpdatePublisher
            .sink { [weak self] sections in
                self?.handleUpdate(sections: sections)
            }
            .store(in: &cancellables)
    }

    private func handleUpdate(sections: [PhotosGridViewSection]) {
        let items = sections.flatMap(\.items)
        if let vm = photoViewModel, let section = vm.sections.first {
            let section = GridViewSection(id: section.id, items: items)
            vm.sections = [section]
            objectWillChange.send()
        } else {
            let section = GridViewSection(items: items)
            photoViewModel = makePhotoViewModel(sections: [section])
        }
    }

    private func makePhotoViewModel(sections: [GridViewSection]) -> PhotoListingGridViewModel {
        .init(sections: sections) { [weak self] in
            self?.didShowLastPhotoItem()
        }
    }
}

extension AlbumDetailGridViewModel {
    struct Dependencies {
        let itemViewModelFactory: CachingPhotoItemViewModelFactoryProtocol
        let photosGridViewModel: any PhotosGridViewModelProtocol
    }
}
