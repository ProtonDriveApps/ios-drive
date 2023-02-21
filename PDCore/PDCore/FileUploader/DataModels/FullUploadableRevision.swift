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

#warning("remove")
struct FullUploadableRevision {
    let blocks: [FullUploadableBlock]
    let thumbnail: FullUploadableThumbnail?

    func block(atIndex index: Int) -> FullUploadableBlock {
        blocks[index]
    }
}

// `Uploader` models, to be deleted after the new `FileUploader` is signed off
struct UploadableRevision2 {
    let blocks: [UploadBlock]
    let thumbnail: Thumbnail?
    let revision: Revision
}

struct UploadableBlock2 {
    let block: UploadBlock
    let revision: Revision

    var uploadableRevision: UploadableRevision2 {
        UploadableRevision2(blocks: [block], thumbnail: nil, revision: revision)
    }
}

struct FullUploadableRevision2 {
    let blocks: [FullUploadableBlock2]
    let thumbnail: FullUploadableThumbnail?
    let revision: Revision

    func block(atIndex index: Int) -> UploadableBlock2 {
        UploadableBlock2(block: blocks[index].block, revision: revision)
    }
}

struct FullUploadableBlock2 {
    let index: Int
    let localURL: URL
    let remoteURL: URL
    let block: UploadBlock
    let revision: Revision

    var uploadable: UploadableBlock2 {
        UploadableBlock2(block: block, revision: revision)
    }
}

extension UploadBlock {
    var unsafeFullUploadableBlock2: FullUploadableBlock2? {
        guard let localURL = localUrl,
              let remoteURLString = uploadUrl,
              let remoteURL = URL(string: remoteURLString) else {
                  return nil
              }
        return FullUploadableBlock2(index: index, localURL: localURL, remoteURL: remoteURL, block: self, revision: revision)
    }

    func uploadableBlock() throws -> FullUploadableBlock2 {
        let uploadableBlock: FullUploadableBlock2 = try managedObjectContext!.performAndWait {
            guard let block = unsafeFullUploadableBlock2 else {
                throw Uploader.Errors.blockLacksMetadata
            }
            return block
        }
        return uploadableBlock
    }
}
