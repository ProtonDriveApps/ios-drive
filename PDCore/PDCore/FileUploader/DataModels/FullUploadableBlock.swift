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

struct FullUploadableBlock {
    let remoteURL: URL
    let uploadToken: String
    let uploadable: UploadableBlock

    var localURL: URL {
        uploadable.localURL
    }
}

extension UploadBlock {
    
    var unsafeFullUploadableBlock: FullUploadableBlock? {
        guard let uploadable = UploadableBlock(block: self),
              let remoteURLString = uploadUrl,
              let remoteURL = URL(string: remoteURLString),
              let token = uploadToken else {
                  return nil
              }
        return FullUploadableBlock(remoteURL: remoteURL, uploadToken: token, uploadable: uploadable)
    }

    func uploadableBlock() throws -> FullUploadableBlock {
        let uploadableBlock: FullUploadableBlock = try managedObjectContext!.performAndWait {
            guard let block = unsafeFullUploadableBlock else {
                throw Uploader.Errors.blockLacksMetadata
            }
            return block
        }
        return uploadableBlock
    }

}
