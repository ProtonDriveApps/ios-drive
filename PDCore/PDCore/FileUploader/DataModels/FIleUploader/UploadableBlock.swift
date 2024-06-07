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

struct UploadableBlock: Equatable {
    let index: Int
    let size: Int
    let hash: String
    let localURL: URL
    let signatureEmail: String
    let encryptedSignature: String
    let verificationToken: String
}

extension UploadableBlock {
    init?(block: UploadBlock, verificationToken: String) {
        let hash = block.sha256.base64EncodedString()
        guard let localURL = block.localUrl,
              let encSignature = block.encSignature,
              let signatureEmail = block.signatureEmail else {
            return nil
        }
        self.index = Int(block.index)
        self.size = Int(block.size)
        self.hash = hash
        self.localURL = localURL
        self.signatureEmail = signatureEmail
        self.encryptedSignature = encSignature
        self.verificationToken = verificationToken
    }
}
