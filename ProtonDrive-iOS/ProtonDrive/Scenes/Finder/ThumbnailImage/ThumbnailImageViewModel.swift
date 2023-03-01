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

class ThumbnailImageViewModel {
    private(set) var thumbnail: Thumbnail?
    private let loader: ThumbnailLoader?
    private let id: NodeIdentifier
    private let node: Node

    private var startedDownload = false

    init(node: Node, loader: ThumbnailLoader? = nil) {
        self.loader = loader
        self.id = node.identifier
        self.node = node

        if let file = node as? File {
            thumbnail = file.activeRevision?.thumbnail
        }
    }

    func load() {
        guard  clear == nil,
               !startedDownload else {
            return
        }

        self.loader?.loadThumbnail(with: self.id)
        startedDownload = true
    }

    var clear: Data? {
        thumbnail?.clearThumbnail
    }
}
