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

import PDCore
import PDCoreIOS

final class BookmarkContainer {
    private let storageManager: StorageManager
    private let remoteDataSource: BookmarksRemoteDataSource
    private let localDataSource: BookmarksLocalDataSource
    private let deleteDataSource: DeleteBookmarkDataSource
    private let featureFlagsController: FeatureFlagsControllerProtocol

    init(tower: Tower, featureFlagsController: FeatureFlagsControllerProtocol) {
        storageManager = tower.storage
        remoteDataSource = tower.client
        localDataSource = tower.storage
        deleteDataSource = tower.client
        self.featureFlagsController = featureFlagsController
    }

    func makeBookmarksScanner() -> BookmarksScannerInteractorProtocol {
        let bookmarksRepository = BookmarksRepository(remoteDataSource: remoteDataSource, localDataSource: localDataSource)
        let bookmarksScanner = BookmarksScannerInteractor(repository: bookmarksRepository)
        let featureFlagsControlledScanner = FeatureFlagsBookmarksScannerInteractor(interactor: bookmarksScanner, featureFlagsController: featureFlagsController)
        return featureFlagsControlledScanner
    }

    func makeController(for bookmark: CoreDataBookmark) -> BookmarkOpeningControllerProtocol {
        let dataSource = StorageBookmarkPasswordDataSource(bookmark: bookmark, storage: storageManager)
        let interactor = BookmarkUrlConstructorInteractor(dataSource: dataSource, baseOrigin: Constants.clientApiConfig.baseOrigin)
        let coordinator = BookmarkOpeningCoordinator()
        let controller = BookmarkOpeningController(
            interactor: interactor,
            coordinator: coordinator,
            errorController: UserMessageHandler()
        )
        return controller
    }

    func makeBookmarkManagerViewMode(for bookmark: CoreDataBookmark) -> BookmarkManagerViewModelProtocol {
        let dataSource = StorageBookmarkPasswordDataSource(bookmark: bookmark, storage: storageManager)
        let interactor = BookmarkUrlConstructorInteractor(dataSource: dataSource, baseOrigin: Constants.clientApiConfig.baseOrigin)
        let urlDelivery = UIPasteSystemBookmarkUrlDeliveryResource()
        let deleteUseCase = BookmarkDeleteUseCase(bookmark: bookmark, storageManager: storageManager, deleteDataSource: deleteDataSource)
        return BookmarkManagerViewModel(urlConstructor: interactor, urlDelivery: urlDelivery, deleteUseCase: deleteUseCase, messageHandler: UserMessageHandler())
    }
}
