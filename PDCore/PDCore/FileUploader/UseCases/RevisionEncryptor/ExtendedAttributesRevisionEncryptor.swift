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
import CoreData

typealias EncryptAndSign = (PlainData, ArmoredEncryptionKey, ArmoredSigningKey, Passphrase) throws -> ArmoredMessage

final class ExtendedAttributesRevisionEncryptor: RevisionEncryptor {
    private let encryptAndSign: EncryptAndSign
    private let signersKitFactory: SignersKitFactoryProtocol
    private let maxBlockSize: Int
    private let progress: Progress
    private let moc: NSManagedObjectContext

    private var isCancelled = false
    private var isExecuting = false

    init(
        encryptAndSign: @escaping EncryptAndSign = Encryptor.encryptAndSignWithCompression,
        signersKitFactory: SignersKitFactoryProtocol,
        maxBlockSize: Int,
        progress: Progress,
        moc: NSManagedObjectContext
    ) {
        self.encryptAndSign = encryptAndSign
        self.signersKitFactory = signersKitFactory
        self.maxBlockSize = maxBlockSize
        self.progress = progress
        self.moc = moc
    }

    func encrypt(_ draft: CreatedRevisionDraft, completion: @escaping Completion) {
        guard !isCancelled, !isExecuting else { return }
        isExecuting = true
        let revision = draft.revision

        ConsoleLogger.shared?.log("STAGE: 1.3 📝 Encrypt xAttr started", osLogType: FileUploader.self)

        moc.perform {
            let revision = revision.in(moc: self.moc)
            do {
                guard let signatureEmail = revision.signatureAddress else { throw RevisionEncryptorError.noSignatureEmailInRevision }
                let signersKit = try self.signersKitFactory.make(forSigner: .address(signatureEmail))
                let publicNodeKey = try Encryptor.getPublicKey(fromPrivateKey: revision.file.nodeKey)
                let addressKey = signersKit.addressKey.privateKey
                let addressPassphrase = signersKit.addressPassphrase

                let totalSize: Int
                let blockSizes: [Int]
                if let fileSize = draft.localURL.fileSize {
                    totalSize = fileSize
                    blockSizes = fileSize.split(divisor: self.maxBlockSize)
                } else {
                    totalSize = .zero
                    blockSizes = []
                }
                let modificationTime = draft.localURL.contentModificationDate ?? Date()

                let commonAttributes = ExtendedAttributes.Common(modificationTime: modificationTime, size: totalSize, blockSizes: blockSizes)
                let clearExtendedAttributes = try ExtendedAttributes(common: commonAttributes).encoded()
                let xAttr = try self.encryptAndSign(clearExtendedAttributes, publicNodeKey, addressKey, addressPassphrase)

                revision.xAttributes = xAttr
                try self.moc.saveOrRollback()

                ConsoleLogger.shared?.log("STAGE: 1.3 📝 Encrypt xAttr finished ✅", osLogType: FileUploader.self)

                self.progress.complete()
                completion(.success)

            } catch {
                ConsoleLogger.shared?.log("STAGE: 1.3 📝 Encrypt xAttr finished ❌", osLogType: FileUploader.self)
                completion(.failure(error))
            }
        }
    }

    func cancel() {
        isCancelled = true
    }
}
