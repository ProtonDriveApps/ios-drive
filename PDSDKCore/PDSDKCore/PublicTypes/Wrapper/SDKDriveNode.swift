// Copyright (c) 2026 Proton AG
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
import ProtonDriveSDK
import PDCore

public extension SDKDriveNode {

    private func map<T>(
        file: (ProtonDriveSDK.FileNode) -> T,
        folder: (ProtonDriveSDK.FolderNode) -> T,
        album: (ProtonDriveSDK.AlbumNode) -> T,
        photo: (ProtonDriveSDK.PhotoNode) -> T
    ) -> T {
        switch self {
        case .file(let f):   return file(f)
        case .folder(let d): return folder(d)
        case .album(let a): return album(a)
        case .photo(let p): return photo(p)
        }
    }

    var uid: SDKNodeUid {
        map(file: { $0.uid }, folder: { $0.uid }, album: { $0.uid }, photo: { $0.uid })
    }

    var parentUid: SDKNodeUid? {
        map(file: { $0.parentUid }, folder: { $0.parentUid }, album: { $0.parentUid }, photo: { $0.parentUid })
    }

    var name: String {
        map(
            file: { $0.name.value ?? String.randomPlaceholder },
            folder: { $0.name.value ?? String.randomPlaceholder },
            album: { $0.name.value ?? String.randomPlaceholder },
            photo: { $0.name.value ?? String.randomPlaceholder }
        )
    }

    var creationTime: TimeInterval {
        map(
            file: { $0.creationTime },
            folder: { $0.creationTime },
            album: { $0.creationTime },
            photo: { $0.creationTime }
        )
    }

    var trashTime: TimeInterval? {
        map(file: { $0.trashTime }, folder: { $0.trashTime }, album: { $0.trashTime }, photo: { $0.trashTime })
    }

    var nameAuthor: SDKAuthor {
        map(file: { $0.nameAuthor }, folder: { $0.nameAuthor }, album: { $0.nameAuthor }, photo: { $0.nameAuthor })
    }

    var keyAuthor: SDKAuthor {
        map(file: { $0.keyAuthor }, folder: { $0.keyAuthor }, album: { $0.keyAuthor }, photo: { $0.keyAuthor })
    }

    var ownedBy: SDKOwnedBy {
        map(file: { $0.ownedBy }, folder: { $0.ownedBy }, album: { $0.ownedBy }, photo: { $0.ownedBy })
    }

    var activeRevision: FileRevision? {
        map(file: { $0.activeRevision }, folder: { _ in nil }, album: { _ in nil }, photo: { $0.activeRevision })
    }
}
