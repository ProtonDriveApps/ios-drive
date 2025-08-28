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

import PDCoreIOS

final class BookmarksScannerInteractor: BookmarksScannerInteractorProtocol {
    private let repository: BookmarksRepositoryProtocol

    init(repository: BookmarksRepositoryProtocol) {
        self.repository = repository
    }

    func scan() async throws {
        _ = try await repository.retrieve()
    }
}

final class FeatureFlagsBookmarksScannerInteractor: BookmarksScannerInteractorProtocol {
    private let interactor: BookmarksScannerInteractorProtocol
    private let featureFlagsController: FeatureFlagsControllerProtocol

    init(interactor: BookmarksScannerInteractorProtocol, featureFlagsController: FeatureFlagsControllerProtocol) {
        self.interactor = interactor
        self.featureFlagsController = featureFlagsController
    }

    func scan() async throws {
        guard featureFlagsController.hasBookmarks else { return }
        try await interactor.scan()
    }
}
