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

import PDCore

protocol ThumbnailsControllersContainerProtocol {
    func makeSmallThumbnailController(id: PhotoId) -> ThumbnailController
    func makeBigThumbnailController(id: PhotoId) -> ThumbnailController
}

final class ThumbnailsControllersContainer: ThumbnailsControllersContainerProtocol {
    struct Dependencies {
        let tower: Tower
        let metadataController: MetadataControllerProtocol
    }

    private let dependencies: Dependencies
    private let factory = ThumbnailsControllerFactory()
    private lazy var smallThumbnailsUrlsController = factory.makeUrlsController(
        tower: dependencies.tower,
        type: .default
    )
    private lazy var bigThumbnailsUrlsController = factory.makeUrlsController(
        tower: dependencies.tower,
        type: .photos
    )
    private lazy var smallThumbnailsRepository = makeSynchronousRepository()
    private lazy var bigThumbnailsRepository = makeSynchronousRepository()
    lazy var smallThumbnailsController = factory.makeSmallThumbnailsController(tower: dependencies.tower)
    lazy var bigThumbnailsController = factory.makeBigThumbnailsController(tower: dependencies.tower)

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func makeSmallThumbnailController(id: PhotoId) -> ThumbnailController {
        factory.makeThumbnailController(
            tower: dependencies.tower,
            thumbnailsController: smallThumbnailsController,
            urlsController: smallThumbnailsUrlsController,
            metadataController: dependencies.metadataController,
            synchronousRepository: smallThumbnailsRepository,
            id: id,
            type: .default
        )
    }

    func makeBigThumbnailController(id: PhotoId) -> ThumbnailController {
        factory.makeThumbnailController(
            tower: dependencies.tower,
            thumbnailsController: bigThumbnailsController,
            urlsController: bigThumbnailsUrlsController,
            metadataController: dependencies.metadataController,
            synchronousRepository: bigThumbnailsRepository,
            id: id,
            type: .photos
        )
    }

    private func makeSynchronousRepository() -> SynchronousThumbnailRepository {
        let configuration = MemoryManagedStringKeyedDataStorage.Configuration(countLimit: 300, totalCostLimit: 10_000_000)
        let storage = MemoryManagedStringKeyedDataStorage(configuration: configuration)
        return ConcreteSynchronousThumbnailRepository(storage: storage)
    }
}
