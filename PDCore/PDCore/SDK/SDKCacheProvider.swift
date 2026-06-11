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

public final class SDKCacheProvider {
    public private(set) lazy var entityCacheURL = groupContainerDirectory.appending(path: "SDKEntityCache.sqlite")
    public private(set) lazy var secretCacheURL = groupContainerDirectory.appending(path: "SDKSecretCache.sqlite")

    private let groupContainerDirectory: URL

    init(groupContainerDirectory: URL) {
        self.groupContainerDirectory = groupContainerDirectory
    }

    func cleanUp() {
        do {
            try makeURLsWithSQLiteExtensions(for: [entityCacheURL, secretCacheURL]).forEach { currentURL in
                if FileManager.default.fileExists(atPath: currentURL.path(percentEncoded: false)) {
                    try FileManager.default.removeItem(at: currentURL)
                }
            }
        } catch {
            Log.error("Failed to clean up SDK caches", error: error, domain: .sdk)
        }
    }

    private func makeURLsWithSQLiteExtensions(for sqliteFileURLs: [URL]) -> [URL] {
        return sqliteFileURLs.flatMap { currentURL in
            let fileName = currentURL.lastPathComponent.fileName
            let directory = currentURL.deletingLastPathComponent()

            return [
                directory.appending(component: fileName + ".sqlite"),
                directory.appending(component: fileName + ".sqlite-wal"),
                directory.appending(component: fileName + ".sqlite-shm")
            ]
        }
    }
}
