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

extension FullUploadableBlock {
    init?(block: UploadBlock) {
        guard let remoteURLString = block.uploadUrl,
              let remoteURL = URL(string: remoteURLString),
              let token = block.uploadToken,
              let uploadableBlock = UploadableBlock(block: block) else {
            return nil
        }

        self.remoteURL = remoteURL
        self.uploadToken = token
        self.uploadable = uploadableBlock
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
}

extension Block {
    var asUploadBlock: UploadBlock? {
        self as? UploadBlock
    }
}
