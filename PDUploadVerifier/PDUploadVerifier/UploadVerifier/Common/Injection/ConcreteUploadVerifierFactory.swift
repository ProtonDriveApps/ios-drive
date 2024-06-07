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
import PDClient
import CoreData

public struct ConcreteUploadVerifierFactory: UploadVerifierFactory {
    public init() {}

    public func make(storage: StorageManager, moc: NSManagedObjectContext, client: Client, decryptionResource: DecryptionResource, identifier: UploadingFileIdentifier) async throws -> UploadVerifier {
        let decryptionInfoDataSource = CoreDataNodeDecryptionInfoDataSource(storage: storage, moc: moc)
        let infoRepository = DecryptingVerificationInfoRepository(
            verificationDataSource: RemoteVerificationDataSource(client: client),
            decryptionInfoDataSource: decryptionInfoDataSource,
            decryptionResource: decryptionResource
        )
        let urlDataSource = CoreDataUploadBlockUrlDataSource(storage: storage, managedObjectContext: moc)
        let verificationInteractor = DecryptingBlockVerificationInteractor(urlDataSource: urlDataSource, decryptionResource: decryptionResource, filePrefixResource: ConcreteFilePrefixResource())
        return try await BlockDecryptingUploadVerifier(
            infoRepository: infoRepository,
            verificationInteractor: verificationInteractor,
            identifier: identifier
        )
    }
}
