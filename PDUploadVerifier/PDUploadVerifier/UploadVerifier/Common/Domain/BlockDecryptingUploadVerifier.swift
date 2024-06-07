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

import PDCore

/// Steps:
/// 1. Initialization downloads the file contentKey and verificationCode and uses them to decrypt sessionKey.
/// 2. Verification uses the created sessionKey to decrypt a block and create a verification token.
final class BlockDecryptingUploadVerifier: UploadVerifier {
    private let verificationInteractor: BlockVerificationInteractor
    private let verificationInfo: VerificationInfo

    init(
        infoRepository: VerificationInfoRepository,
        verificationInteractor: BlockVerificationInteractor,
        identifier: UploadingFileIdentifier
    ) async throws {
        self.verificationInteractor = verificationInteractor
        verificationInfo = try await infoRepository.getVerificationInfo(for: identifier)
    }

    func verify(block: VerifiableBlock) async throws -> BlockToken {
        try await verificationInteractor.verify(block: block, verificationInfo: verificationInfo)
    }
}
