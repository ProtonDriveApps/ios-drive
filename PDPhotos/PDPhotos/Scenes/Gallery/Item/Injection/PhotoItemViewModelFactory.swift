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

import Foundation
import PDCore

protocol CachingPhotoItemViewModelFactoryProtocol {
    func makeViewModel(for item: PhotoGridViewItem) -> PhotoItemViewModel
}

final class CachingPhotoItemViewModelFactory: CachingPhotoItemViewModelFactoryProtocol {
    private let factory: (PhotoGridViewItem) -> PhotoItemViewModel
    private let cache: PhotoItemViewModelsCache

    init(cache: PhotoItemViewModelsCache, factory: @escaping (PhotoGridViewItem) -> PhotoItemViewModel) {
        self.cache = cache
        self.factory = factory
    }

    func makeViewModel(for item: PhotoGridViewItem) -> PhotoItemViewModel {
        if let viewModel = cache.viewModels[item.id]?.reference {
            viewModel.setItem(item)
            return viewModel
        } else {
            if cache.viewModels.count > 20000 { // 20k viewModels take < 10MB
                cache.viewModels.removeAll()
            }
            let viewModel = factory(item)
            cache.viewModels[item.id] = WeakReference(reference: viewModel)
            return viewModel
        }
    }
}

// This cache should only bridge view renderings. It contains weak references, so when the view is closed they're
// actually released too.
final class PhotoItemViewModelsCache {
    var viewModels = [AnyVolumeIdentifier: WeakReference<PhotoItemViewModel>]()
}
