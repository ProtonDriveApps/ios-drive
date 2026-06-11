// Copyright (c) 2025 Proton AG
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

import CoreData
import Foundation
import PDCore
import PDCoreIOS
import PDClient

protocol PhotoXAttrBatchBackfiller {
    func execute(reports: [MigrationAnalyzeReport]) async throws
    func send(identifier: AnyVolumeIdentifier, extendedAttributes: ExtendedAttributes) async
}

final class DefaultPhotoXAttrBatchBackfiller: PhotoXAttrBatchBackfiller {
    private let client: XAttrBackfillRepository
    private let encryptor: EncryptionResource
    private let keyReader: PhotoRevisionReaderProtocol
    private let managedContext: NSManagedObjectContext
    private let signersKitFactory: SignersKitFactoryProtocol

    init(
        client: XAttrBackfillRepository,
        encryptor: EncryptionResource,
        keyReader: PhotoRevisionReaderProtocol = PhotoRevisionReader(),
        managedContext: NSManagedObjectContext,
        signersKitFactory: SignersKitFactoryProtocol
    ) {
        self.client = client
        self.encryptor = encryptor
        self.keyReader = keyReader
        self.managedContext = managedContext
        self.signersKitFactory = signersKitFactory
    }

    func execute(reports: [MigrationAnalyzeReport]) async throws {
        await withTaskGroup(of: Void.self) { [weak self] group in
            guard let self else { return }
            for report in reports {
                guard let extendedAttributes = report.extendedAttributes else { continue }
                group.addTask {
                    await self.send(identifier: report.identifier, extendedAttributes: extendedAttributes)
                }
            }
            await group.waitForAll()
        }
    }

    func send(identifier: AnyVolumeIdentifier, extendedAttributes: ExtendedAttributes) async {
        do {
            guard let properties = try await keyReader.read(photoIdentifier: identifier, in: managedContext) else {
                Log.warning("Can't get revision properties, photo \(identifier) doesn't exist", domain: .exifBackfill)
                return
            }
            let signersKit = try signersKitFactory.make(forSigner: .address(properties.signatureEmail))
            let publicNodeKey = try encryptor.getPublicKey(fromPrivateKey: properties.nodeKey)
            let addressKey = signersKit.addressKey.privateKey
            let addressPassphrase = signersKit.addressPassphrase

            let xAttr = try encryptor.encryptAndSignWithCompression(
                try extendedAttributes.encoded(),
                encryptionKey: publicNodeKey,
                signingKey: addressKey,
                passphrase: addressPassphrase
            )

            let parameters = UpdateXAttrEndpoint.Parameters(
                volumeID: identifier.volumeID,
                linkID: identifier.id,
                revisionID: properties.revisionID,
                body: .init(signatureEmail: signersKit.address.email, xAttr: xAttr)
            )
            try await client.updateXAttrs(parameters: parameters)
        } catch {
            Log.error("Backfilling \(identifier) fails", error: error, domain: .exifBackfill)
        }
    }
}
