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

protocol SynchronousThumbnailRepository {
    func load(with id: PhotoId) -> Data?
    func hasData(with id: PhotoId) -> Bool
}

final class ConcreteSynchronousThumbnailRepository: SynchronousThumbnailRepository {
    let type: ThumbnailType

    init(type: ThumbnailType) {
        self.type = type
    }

    func clearThumbnailURL(id: PhotoId) -> URL? {
        let identifier = NodeIdentifier(id.id, "", id.volumeID)
        return PDFileManager.thumbnailURL(for: identifier, type: type)
    }

    func load(with id: PhotoId) -> Data? {
        guard let url = clearThumbnailURL(id: id) else { return nil }
        return try? Data(contentsOf: url)
    }

    func hasData(with id: PhotoId) -> Bool {
        guard let url = clearThumbnailURL(id: id) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }
}
