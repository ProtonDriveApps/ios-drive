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
import PDCore

protocol CachingAlbumGridItemViewModelFactoryProtocol {
    func makeViewModel(for albumID: AnyVolumeIdentifier) -> AlbumGridItemViewModel
}

final class CachingAlbumGridItemViewModelFactory: CachingAlbumGridItemViewModelFactoryProtocol {
    private let factory: (AnyVolumeIdentifier) -> AlbumGridItemViewModel
    private var cache = [AnyVolumeIdentifier: WeakReference<AlbumGridItemViewModel>]()

    init(factory: @escaping (AnyVolumeIdentifier) -> AlbumGridItemViewModel) {
        self.factory = factory
    }

    func makeViewModel(for albumID: AnyVolumeIdentifier) -> AlbumGridItemViewModel {
        if let viewModel = cache[albumID]?.reference {
            return viewModel
        } else {
            if cache.count > 100 {
                cache.removeAll()
            }
            let viewModel = factory(albumID)
            cache[albumID] = WeakReference(reference: viewModel)
            return viewModel
        }
    }
}
