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
import PDClient

struct UploadableRevision: Equatable {
    let identifier: RevisionIdentifier
    let blocks: [UploadableBlock]
    let thumbnail: UploadableThumbnail?
    let signatureEmail: String
}

extension UploadableRevision {
    func makeFull(blockLinks: [BlockUploadLink], thumbnailLink: ThumbnailUploadLink?) -> FullUploadableRevision {
        let bl = zip(blocks, blockLinks).map { (block, link) in block.makeFull(with: link) }
        return FullUploadableRevision(blocks: bl, thumbnail: thumbnail?.makeFull(with: thumbnailLink))
    }
}

private extension UploadableThumbnail {
    func makeFull(with link: ThumbnailUploadLink?) -> FullUploadableThumbnail? {
        guard let link = link else { return nil }
        return FullUploadableThumbnail(uploadURL: link.URL, uploadable: self)
    }
}

private extension UploadableBlock {
    func makeFull(with block: BlockUploadLink) -> FullUploadableBlock {
        FullUploadableBlock(remoteURL: URL(string: block.URL)!, uploadToken: block.token, uploadable: self)
    }
}
