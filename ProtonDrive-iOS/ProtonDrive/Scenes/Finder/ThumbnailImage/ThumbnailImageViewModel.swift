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
import Combine

final class ThumbnailImageViewModel: ObservableObject {
    private(set) var thumbnail: Thumbnail?
    private let loader: SDKThumbnailsDownloaderProtocol?
    private let id: NodeIdentifier?
    private let isThumbnailAvailable: Bool
    private var startedDownload = false

    init(node: Node, loader: SDKThumbnailsDownloaderProtocol? = nil) {
        self.loader = loader
        let identifier = node.identifier
        self.id = identifier

        guard let file = node as? CoreDataFile, !file.isProtonFile else {
            isThumbnailAvailable = false
            return
        }

        let revision = file.activeRevision ?? file.activeRevisionDraft
        thumbnail = revision?.thumbnails.first(where: { $0.type == .default })
        isThumbnailAvailable = thumbnail != nil
    }

    init() {
        loader = nil
        id = nil
        isThumbnailAvailable = false
    }

    func load() {
        guard let id else {
            return
        }
        let v2Path = PDFileManager.getThumbnailURL(for: id, type: .default)
        let url = PDFileManager.clearThumbnailV1URL(for: id, type: .default, shouldCreate: false)
        let hasStoredThumbnail = FileManager.default.fileExists(atPath: url.path) || v2Path != nil
        guard
            isThumbnailAvailable,
            !hasStoredThumbnail,
            UUID(uuidString: id.id) == nil, // Temp uploading id, not legit
            thumbnail?.clearThumbnail == nil,
            id.volumeID != "bookmark",
            !startedDownload
        else { return }

        Task {
            do {
                _ = try await self.loader?.downloadThumbnail(for: id.any(), type: .default)
                await MainActor.run {
                    self.startedDownload = false
                    self.objectWillChange.send()
                }
            } catch {
                Log.error("Download thumbnail failed", error: error, domain: .thumbnails)
            }
        }
        startedDownload = true
    }

    var clear: Data? {
        guard let id, isThumbnailAvailable else { return nil }

        if let url = PDFileManager.getThumbnailURL(for: id, type: .default),
           FileManager.default.fileExists(atPath: url.path) {
            return try? Data(contentsOf: url)
        }

        if let thumbnail, let data = thumbnail.clearThumbnail {
            CoreDataThumbnail.saveClearDataToDisk(clearData: data, type: thumbnail.type, identifier: id)
            return data
        } else if !startedDownload {
            load()
        }
        return nil
    }
}
