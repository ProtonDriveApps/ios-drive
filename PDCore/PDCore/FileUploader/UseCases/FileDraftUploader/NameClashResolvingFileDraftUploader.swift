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

final class NameClashResolvingFileDraftUploader: FileDraftUploader {
    private let cloudFileCreator: CloudFileDraftCreator
    private let validNameDiscoverer: ValidNameDiscoverer
    private let nameReencryptor: FileNameReencryptor
    private let signersKitFactory: SignersKitFactoryProtocol
    private let finalizer: FileDraftUploaderFinalizer

    private(set) var isCancelled = false

    init(
        cloudFileCreator: CloudFileDraftCreator,
        validNameDiscoverer: ValidNameDiscoverer,
        signersKitFactory: SignersKitFactoryProtocol,
        nameReencryptor: FileNameReencryptor,
        finalizer: FileDraftUploaderFinalizer
    ) {
        self.cloudFileCreator = cloudFileCreator
        self.validNameDiscoverer = validNameDiscoverer
        self.signersKitFactory = signersKitFactory
        self.nameReencryptor = nameReencryptor
        self.finalizer = finalizer
    }

    func upload(draft: FileDraft, completion: @escaping Completion) {
        ConsoleLogger.shared?.log("STAGE: 1.1 Upload draft ✍️☁️🥚 started", osLogType: FileUploader.self)
        let uploadableFileDraft = draft.getUploadableFileDraft()

        cloudFileCreator.createNewFileDraft(uploadableFileDraft) { [weak self] result in
            guard let self = self, !self.isCancelled else { return }

            switch result {
            case .success(let uploadedFileDraft):
                do {
                    try self.finalizer.finalize(uploadedFileDraft)
                    ConsoleLogger.shared?.log("STAGE: 1.1 Upload draft ✍️☁️🐣 finished ✅", osLogType: FileUploader.self)
                    completion(.success(uploadedFileDraft))

                } catch {
                    ConsoleLogger.shared?.log("STAGE: 1.1 Upload draft ✍️☁️🍳 finished ❌", osLogType: FileUploader.self)
                    completion(.failure(error))
                }

            case .failure(let error as NSError) where error.code == 2500:
                ConsoleLogger.shared?.log("STAGE: 1.1 Upload draft ✍️☁️🥚 finished find new ♻️ ", osLogType: FileUploader.self)
                self.findNextAvailableName(for: draft, completion: completion)

            case .failure(let error):
                ConsoleLogger.shared?.log("STAGE: 1.1 Upload draft ✍️☁️🍳 finished ❌", osLogType: FileUploader.self)
                completion(.failure(error))
            }
        }
    }

    func cancel() {
        isCancelled = true
    }

    private func findNextAvailableName(for draft: FileDraft, completion: @escaping Completion) {
        let model = FileNameCheckerModel(
            originalName: draft.originalName,
            parent: draft.parent.identifier,
            parentNodeHashKey: draft.parent.nodeHashKey
        )

        validNameDiscoverer.findNextAvailableName(for: model) { [weak self] result in
            guard let self = self, !self.isCancelled else { return }

            switch result {
            case let .success(pair):
                do {
                    let newDraft = try self.makeNewDraftChangingNameParameters(pair, draft: draft)

                    self.upload(draft: newDraft, completion: completion)
                } catch {
                    completion(.failure(error))
                }

            case let .failure(error):
                completion(.failure(error))
            }
        }
    }

    private func makeNewDraftChangingNameParameters(_ pair: NameHashPair, draft: FileDraft) throws -> FileDraft {
        let nameSignatureAddress = draft.nameParameters.nameSignatureAddress
        let signersKit = try signersKitFactory.make(forSigner: .address(nameSignatureAddress))
        let newArmoredName = try nameReencryptor.reencryptFileName(file: draft.file, newName: pair.name, signersKit: signersKit)
        draft.nameParameters = .init(
            hash: pair.hash,
            clearName: pair.name,
            armoredName: newArmoredName,
            nameSignatureAddress: nameSignatureAddress
        )
        return draft
    }

}
