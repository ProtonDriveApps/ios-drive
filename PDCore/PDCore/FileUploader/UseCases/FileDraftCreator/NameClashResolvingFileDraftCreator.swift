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

class NameClashResolvingFileDraftCreator: FileDraftCreator {
    
    private let fileDraftCreator: DefaultFileDraftCreator
    private let validNameDiscoverer: ValidNameDiscoverer
    private let signersKitFactory: SignersKitFactoryProtocol
    private let moc: NSManagedObjectContext
    private var attempt = 0
    
    init(
        fileDraftCreator: DefaultFileDraftCreator,
        validNameDiscoverer: ValidNameDiscoverer,
        signersKitFactory: SignersKitFactoryProtocol,
        moc: NSManagedObjectContext
    ) {
        self.fileDraftCreator = fileDraftCreator
        self.validNameDiscoverer = validNameDiscoverer
        self.signersKitFactory = signersKitFactory
        self.moc = moc
    }
    
    func create(_ draft: FileDraft, completion: @escaping Completion) {
        fileDraftCreator.create(draft) { [unowned self] result in
            self.handleResult(result, for: draft, completion: completion)
        }
    }
    
    private func handleResult(_ result: Result<File, Error>, for file: FileDraft, completion: @escaping Completion) {
        switch result {
        case .success(let file):
            completion(.success(file))
        case .failure(let error as ResponseError) where FileDraftCreatorPolicy.obtainNewName.contains(error.responseCode):
            do {
                let nameResolvingDraft = try file.getNameResolvingFileDraft()
                self.findNextAvailableName(for: nameResolvingDraft, attempt: self.attempt) { [weak self] result in
                    guard let self else { return }
                    self.handleResult(result, for: file, completion: completion)
                }
            } catch {
                completion(.failure(error))
            }
        case .failure(let error):
            completion(.failure(error))
        }
    }
    
    private func uploadDraft(_ draft: FileDraftUploadableDraft, completion: @escaping Completion) {
        Log.info("STAGE: 2.1 Create File draft ✍️☁️🍳 attempt: \(attempt)", domain: .uploader)
        fileDraftCreator.uploadDraft(draft, completion: completion)
    }
    
    private func findNextAvailableName(for draft: FileDraftUploadableDraft, attempt: Int, completion: @escaping Completion) {
        let model = FileNameCheckerModel(
            originalName: draft.clearName,
            parent: draft.parent,
            parentNodeHashKey: draft.parentNodeHashKey
        )

        validNameDiscoverer.findNextAvailableName(for: model) { [weak self] result in
            guard let self, !self.fileDraftCreator.isCancelled else { return }

            switch result {
            case let .success(pair):
                do {
                    let newDraft = try self.makeNewDraftChangingNameParameters(pair, draft: draft)
                    self.attempt += 1
                    self.uploadDraft(newDraft, completion: completion)
                } catch {
                    completion(.failure(error))
                }

            case let .failure(error):
                completion(.failure(error))
            }
        }
    }

    private func makeNewDraftChangingNameParameters(_ pair: NameHashPair, draft: FileDraftUploadableDraft) throws -> FileDraftUploadableDraft {
        let nameSignatureAddress = draft.nameSignatureAddress
        let signersKit = try moc.performAndWait {
            let file = draft.file.in(moc: self.moc)
#if os(macOS)
            let signersKit = try file.getContextShareAddressBasedSignersKit(signersKitFactory: self.signersKitFactory,
                                                                            fallbackSigner: .address(nameSignatureAddress))
#else
            let signersKit = try file.getContextShareAddressBasedSignersKit(signersKitFactory: signersKitFactory)
#endif
            return signersKit
        }
        let newArmoredName = try reencryptFileName(file: draft.file, newName: pair.name, signersKit: signersKit)

        return FileDraftUploadableDraft(
            uploadID: draft.uploadID,
            hash: pair.hash,
            clearName: pair.name,
            armoredName: newArmoredName,
            nameSignatureAddress: nameSignatureAddress,
            nodeKey: draft.nodeKey,
            nodePassphrase: draft.nodePassphrase,
            nodePassphraseSignature: draft.nodePassphraseSignature,
            contentKeyPacket: draft.contentKeyPacket,
            contentKeyPacketSignature: draft.contentKeyPacketSignature,
            parent: draft.parent,
            parentNodeHashKey: draft.parentNodeHashKey,
            mimeType: draft.mimeType,
            clientUID: draft.clientUID,
            file: draft.file
        )
    }
    
    private func reencryptFileName(file: File, newName name: String, signersKit: SignersKit) throws -> String {
        try moc.performAndWait {
            let (_, parentKey) = try file.getDirectParentPack()
            return try Encryptor.encryptAndSign(name, key: parentKey, addressPassphrase: signersKit.addressPassphrase, addressPrivateKey: signersKit.addressKey.privateKey)
        }
    }
    
    func cancel() {
        fileDraftCreator.cancel()
    }
}
