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

final class NameClashResolvingFileDraftUploader: FileDraftUploader {
    private let cloudFileCreator: CloudFileDraftCreator
    private let validNameDiscoverer: ValidNameDiscoverer
    private let nameReencryptor: FileNameReencryptor
    private let signersKitFactory: SignersKitFactoryProtocol

    private(set) var isCancelled = false

    init(
        cloudFileCreator: CloudFileDraftCreator,
        validNameDiscoverer: ValidNameDiscoverer,
        signersKitFactory: SignersKitFactoryProtocol,
        nameReencryptor: FileNameReencryptor
    ) {
        self.cloudFileCreator = cloudFileCreator
        self.validNameDiscoverer = validNameDiscoverer
        self.signersKitFactory = signersKitFactory
        self.nameReencryptor = nameReencryptor
    }

    func upload(draft file: File, completion: @escaping Completion) {
        guard !isCancelled else { return }

        ConsoleLogger.shared?.log("STAGE: 2 Upload draft ✍️☁️🥚 started", osLogType: FileUploader.self)

        do {
            let nameResolvingDraft = try file.getNameResolvingFileDraft()
            uploadDraft(nameResolvingDraft, attempt: 0, completion: completion)
        } catch {
            ConsoleLogger.shared?.log("STAGE: 2 Upload draft ✍️☁️🍳 finished ❌", osLogType: FileUploader.self)
            completion(.failure(error))
        }
    }

    fileprivate func uploadDraft(_ draft: NameResolvingFileDraft, attempt: Int, completion: @escaping Completion) {
        guard !isCancelled else { return }

        let uploadableFileDraft = UploadableFileDraft(
            shareID: draft.parent.shareID,
            parentLinkID: draft.parent.nodeID,
            armoredName: draft.armoredName,
            nameHash: draft.hash,
            nodeKey: draft.nodeKey,
            nodePassphrase: draft.nodePassphrase,
            nodePassphraseSignature: draft.nodePassphraseSignature,
            signatureAddress: draft.nameSignatureAddress,
            contentKeyPacket: draft.contentKeyPacket,
            contentKeyPacketSignature: draft.contentKeyPacketSignature,
            mimeType: draft.mimeType
        )

        cloudFileCreator.createNewFileDraft(uploadableFileDraft) { [weak self] result in
            guard let self = self, !self.isCancelled else { return }

            switch result {
            case .success(let uploadedFileDraft):
                do {
                    let nameHash = uploadableFileDraft.nameHash
                    let armoredName = uploadableFileDraft.armoredName
                    try self.finalize(draft.file, uploaded: uploadedFileDraft, nameHash: nameHash, armoredName: armoredName)
                    ConsoleLogger.shared?.log("STAGE: 2.1 Upload draft ✍️☁️🐣 finished ✅, attempt: \(attempt)", osLogType: FileUploader.self)
                    completion(.success(draft.file))

                } catch {
                    ConsoleLogger.shared?.log("STAGE: 2.1 Upload draft ✍️☁️🍳 finished ❌, attempt: \(attempt)", osLogType: FileUploader.self)
                    completion(.failure(error))
                }

            case .failure(let error as ResponseError) where error.responseCode == 2500:
                ConsoleLogger.shared?.log("STAGE: 2.1 Upload draft ✍️☁️🥚 finished find new ♻️, attempt: \(attempt)", osLogType: FileUploader.self)
                self.findNextAvailableName(for: draft, attempt: attempt, completion: completion)

            case .failure(let error):
                ConsoleLogger.shared?.log("STAGE: 2.1 Upload draft ✍️☁️🍳 finished ❌, attempt: \(attempt)", osLogType: FileUploader.self)
                completion(.failure(error))
            }
        }
    }

    func cancel() {
        isCancelled = true
    }

    private func findNextAvailableName(for draft: NameResolvingFileDraft, attempt: Int, completion: @escaping Completion) {
        let model = FileNameCheckerModel(
            originalName: draft.clearName,
            parent: draft.parent,
            parentNodeHashKey: draft.parentNodeHashKey
        )

        validNameDiscoverer.findNextAvailableName(for: model) { [weak self] result in
            guard let self = self, !self.isCancelled else { return }

            switch result {
            case let .success(pair):
                do {
                    let newDraft = try self.makeNewDraftChangingNameParameters(pair, draft: draft)
                    self.uploadDraft(newDraft, attempt: attempt + 1, completion: completion)
                } catch {
                    completion(.failure(error))
                }

            case let .failure(error):
                completion(.failure(error))
            }
        }
    }

    private func makeNewDraftChangingNameParameters(_ pair: NameHashPair, draft: NameResolvingFileDraft) throws -> NameResolvingFileDraft {
        let nameSignatureAddress = draft.nameSignatureAddress
        let signersKit = try signersKitFactory.make(forSigner: .address(nameSignatureAddress))
        let newArmoredName = try nameReencryptor.reencryptFileName(file: draft.file, newName: pair.name, signersKit: signersKit)

        return NameResolvingFileDraft(
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
            file: draft.file
        )
    }

    func finalize(_ file: File, uploaded: RemoteUploadedNewFile, nameHash: String, armoredName: Armored) throws {
        guard let moc = file.moc else { throw File.noMOC() }

        try moc.performAndWait {
            file.id = uploaded.fileID
            file.activeRevisionDraft?.id = uploaded.revisionID

            file.name = armoredName
            file.nodeHash = nameHash

            file.clearName = nil

            try moc.saveOrRollback()
        }
    }
}

struct NameResolvingFileDraft: Equatable {
    let hash: String
    let clearName: String
    let armoredName: Armored
    let nameSignatureAddress: String
    let nodeKey: String
    let nodePassphrase: String
    let nodePassphraseSignature: String
    let contentKeyPacket: String
    let contentKeyPacketSignature: String
    let parent: NodeIdentifier
    let parentNodeHashKey: String
    let mimeType: String
    let file: File
}

extension File {
    func getNameResolvingFileDraft() throws -> NameResolvingFileDraft {
        guard let moc = moc else { throw File.noMOC() }

        return try moc.performAndWait {
            guard isCreatingFileDraft() else {
                throw invalidState("The file is not in the correct state")
            }

            guard let parentLink = parentLink else {
                throw invalidState("Uploadable file draft must have a parent link.")
            }

            let clearParentNodeHashKey = try parentLink.decryptNodeHashKey()

            guard let armoredName = name else {
                throw invalidState("NameChangeDraft must have an encrypted name.")
            }

            guard let contentKeyPacket = contentKeyPacket else {
                throw invalidState("Uploadable file draft must have a content key packet.")
            }

            guard let contentKeyPacketSignature = contentKeyPacketSignature else {
                throw invalidState("Uploadable file draft must have a content key packet signature.")
            }

            return NameResolvingFileDraft(
                hash: nodeHash,
                clearName: decryptedName,
                armoredName: armoredName,
                nameSignatureAddress: signatureEmail,
                nodeKey: nodeKey,
                nodePassphrase: nodePassphrase,
                nodePassphraseSignature: nodePassphraseSignature,
                contentKeyPacket: contentKeyPacket,
                contentKeyPacketSignature: contentKeyPacketSignature,
                parent: parentLink.identifier,
                parentNodeHashKey: clearParentNodeHashKey,
                mimeType: mimeType,
                file: self
            )
        }
    }
}
