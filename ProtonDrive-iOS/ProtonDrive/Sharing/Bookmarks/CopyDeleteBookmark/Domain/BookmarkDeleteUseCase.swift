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

protocol BookmarkDeleteUseCaseProtocol {
    func delete() async throws
}

final class BookmarkDeleteUseCase: BookmarkDeleteUseCaseProtocol {
    private let bookmark: CoreDataBookmark
    private let storageManager: StorageManager
    private let deleteDataSource: DeleteBookmarkDataSource

    init(bookmark: CoreDataBookmark, storageManager: StorageManager, deleteDataSource: DeleteBookmarkDataSource) {
        self.bookmark = bookmark
        self.storageManager = storageManager
        self.deleteDataSource = deleteDataSource
    }

    func delete() async throws {
        let context = storageManager.backgroundContext

        let token = await context.perform {
            let bookmark = self.bookmark.in(moc: context)
            return bookmark.token
        }

        try await deleteDataSource.deleteBookmark(token: token)

        try await context.perform {
            let bookmark = self.bookmark.in(moc: context)
            context.delete(bookmark)
            try context.saveOrRollback()
        }
    }
}
