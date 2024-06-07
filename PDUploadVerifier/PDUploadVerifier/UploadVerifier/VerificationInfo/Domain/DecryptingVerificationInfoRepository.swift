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
import PDCore
import ProtonCoreKeyManager

typealias Email = String
typealias PublicKeysDataSource = (Email) -> [PublicKey]

final class DecryptingVerificationInfoRepository: VerificationInfoRepository {
    private let verificationDataSource: VerificationDataSource
    private let decryptionInfoDataSource: NodeDecryptionInfoDataSource
    private let decryptionResource: DecryptionResource

    init(
        verificationDataSource: VerificationDataSource,
        decryptionInfoDataSource: NodeDecryptionInfoDataSource,
        decryptionResource: DecryptionResource
    ) {
        self.verificationDataSource = verificationDataSource
        self.decryptionInfoDataSource = decryptionInfoDataSource
        self.decryptionResource = decryptionResource
    }

    func getVerificationInfo(for identifier: UploadingFileIdentifier) async throws -> VerificationInfo {
        let parameters = GetVerificationDataParameters(shareId: identifier.shareId, linkId: identifier.nodeId, revisionId: identifier.revisionId)
        let verificationData = try await verificationDataSource.getData(parameters: parameters)
        guard let verificationCode = Data(base64Encoded: verificationData.verificationCode) else {
            throw UploadVerifierError.invalidResponse
        }

        // We can trust our local cache to get the nodeKey nodeKey and passphrase
        let decryptionInfo = try decryptionInfoDataSource.getDecryptionInfo(of: identifier.identifier)
        let sessionKey = try decryptSessionKey(contentKeyPacket: verificationData.contentKeyPacket, nodePassphrase: decryptionInfo.decryptedPassphrase, nodeKey: decryptionInfo.nodeKey)
        return VerificationInfo(sessionKey: sessionKey, verificationCode: verificationCode)
    }

    private func decryptSessionKey(
        contentKeyPacket: String,
        nodePassphrase: String,
        nodeKey: String
    ) throws -> SessionKey {
        guard let contentKeyPacket = Data(base64Encoded: contentKeyPacket) else {
            throw UploadVerifierError.invalidResponse
        }

        let nodeDecryptionKey = DecryptionKey(privateKey: nodeKey, passphrase: nodePassphrase)
        return try decryptionResource.decryptKeyPacket(contentKeyPacket, decryptionKey: nodeDecryptionKey)
    }
}
