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

class ExtendedAttributesRevisionEncryptor: RevisionEncryptor {
   let encryptAndSign: EncryptAndSign
   let signersKitFactory: SignersKitFactoryProtocol
   let maxBlockSize: Int
   let progress: Progress
   let moc: NSManagedObjectContext
   let digestBuilder: DigestBuilder

   var isCancelled = false
   var isExecuting = false

    init(
        encryptAndSign: @escaping EncryptAndSign = Encryptor.encryptAndSignWithCompression,
        signersKitFactory: SignersKitFactoryProtocol,
        maxBlockSize: Int,
        progress: Progress,
        moc: NSManagedObjectContext,
        digestBuilder: DigestBuilder
    ) {
        self.encryptAndSign = encryptAndSign
        self.signersKitFactory = signersKitFactory
        self.maxBlockSize = maxBlockSize
        self.progress = progress
        self.moc = moc
        self.digestBuilder = digestBuilder
    }

    func encrypt(_ draft: CreatedRevisionDraft, completion: @escaping Completion) {
        guard !isCancelled, !isExecuting else { return }
        isExecuting = true
        let revision = draft.revision

        Log.info("STAGE: 1.3 📝 Encrypt xAttr started. UUID: \(draft.uploadID)", domain: .uploader)

        moc.perform { [weak self] in
            guard let self, !self.isCancelled else { return }
            
            let revision = revision.in(moc: self.moc)
            
            do {
#if os(macOS)
                guard let signatureEmail = revision.signatureAddress else { throw RevisionEncryptorError.noSignatureEmailInRevision }
                let signersKit = try self.signersKitFactory.make(forSigner: .address(signatureEmail))
#else
                let addressID = try revision.file.getContextShareAddressID()
                let signersKit = try signersKitFactory.make(forAddressID: addressID)
#endif
                let publicNodeKey = try Encryptor.getPublicKey(fromPrivateKey: revision.file.nodeKey)
                let addressKey = signersKit.addressKey.privateKey
                let addressPassphrase = signersKit.addressPassphrase

                let clearExtendedAttributes = try self.getXAttrs(draft)
                let xAttr = try self.encryptAndSign(clearExtendedAttributes.encoded(), publicNodeKey, addressKey, addressPassphrase)

                revision.clearXAttributes = clearExtendedAttributes
                revision.xAttributes = xAttr
                try self.moc.saveOrRollback()

                Log.info("STAGE: 1.3 📝 Encrypt xAttr finished ✅. UUID: \(draft.uploadID)", domain: .uploader)

                self.progress.complete()
                completion(.success)
                
            } catch {
                Log.info("STAGE: 1.3 📝 Encrypt xAttr finished ❌. UUID: \(draft.uploadID)", domain: .uploader)
                completion(.failure(error))
            }
        }
    }
    
    func getXAttrs(_ draft: CreatedRevisionDraft) throws -> ExtendedAttributes {
        let commonAttributes = commonAttributes(draft)
        return ExtendedAttributes(common: commonAttributes)
    }
    
    func commonAttributes(_ draft: CreatedRevisionDraft) -> ExtendedAttributes.Common {
        let (totalSize, blockSizes) = sizes(draft)
        let modificationTime = modificationDate(draft)
        let digests = digest()
        return ExtendedAttributes.Common(modificationTime: modificationTime, size: totalSize, blockSizes: blockSizes, digests: digests)
    }
    
    func sizes(_ draft: CreatedRevisionDraft) -> (totalSize: Int, blockSizes: [Int]) {
        let fileSize = draft.size
        return (fileSize, fileSize.split(divisor: self.maxBlockSize))
    }
    
    func modificationDate(_ draft: CreatedRevisionDraft) -> String {
        ISO8601DateFormatter().string(from: draft.localURL.contentModificationDate ?? Date())
    }
    
    func digest() -> ExtendedAttributes.Digests {
        let sha1 = self.digestBuilder.getResult().hexString()
        return ExtendedAttributes.Digests(sha1: sha1)
    }

    func cancel() {
        isCancelled = true
    }
}
