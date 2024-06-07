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

protocol BlockVerificationInteractor {
    func verify(block: VerifiableBlock, verificationInfo: VerificationInfo) async throws -> BlockToken
}

final class DecryptingBlockVerificationInteractor: BlockVerificationInteractor {
    private let urlDataSource: UploadBlockUrlDataSource
    private let decryptionResource: DecryptionResource
    private let filePrefixResource: FilePrefixResource

    init(urlDataSource: UploadBlockUrlDataSource, decryptionResource: DecryptionResource, filePrefixResource: FilePrefixResource) {
        self.urlDataSource = urlDataSource
        self.decryptionResource = decryptionResource
        self.filePrefixResource = filePrefixResource
    }

    func verify(block: VerifiableBlock, verificationInfo: VerificationInfo) async throws -> BlockToken {
        let url = try await urlDataSource.getBlockUrl(for: block)
        try decryptionResource.decryptInStream(url: url, sessionKey: verificationInfo.sessionKey)
        let tokenBytesCount = verificationInfo.verificationCode.count
        let encryptedPacketPrefix = try filePrefixResource.getData(url: url, count: tokenBytesCount)
        let tokenData = makeXor(lhs: encryptedPacketPrefix, rhs: verificationInfo.verificationCode, count: tokenBytesCount)
        let token = tokenData.base64EncodedString()
        return token
    }

    private func makeXor(lhs: Data, rhs: Data, count: Int) -> Data {
        var result = Data(count: count)
        for i in 0 ..< count {
            result[i] = (lhs[safe: i] ?? 0) ^ (rhs[safe: i] ?? 0)
        }
        return result
    }
}
