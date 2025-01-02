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
import Combine

final class ShareLinkModel {
    private let node: Node
    private let shareURL: ShareURL
    private let shareID: String
    private let shareURLID: String
    private let repository: SharedLinkRepository
    private let sharedLinkSubject: CurrentValueSubject<SharedLink, Never>
    private var cancellables = Set<AnyCancellable>()

    private var sharedLink: SharedLink
    private var storage: StorageManager

    init(
        node: Node,
        sharedLinkSubject: CurrentValueSubject<SharedLink, Never>,
        shareURL: ShareURL,
        repository: SharedLinkRepository,
        storage: StorageManager
    ) {
        self.node = node
        self.shareURL = shareURL
        self.repository = repository
        self.sharedLinkSubject = sharedLinkSubject
        self.sharedLink = sharedLinkSubject.value
        self.shareURLID = sharedLinkSubject.value.id
        self.shareID = sharedLinkSubject.value.shareID
        self.storage = storage

        runChecksOnNode(node)
    }

    func runChecksOnNode(_ node: Node) {
        guard let moc = node.moc  else { return }

        moc.perform {
            let share = node.primaryDirectShare
            _ = try? share?.decryptPassphrase()
        }
    }

    var name: String {
        node.decryptedName
    }

    var sharedLinkPublisher: AnyPublisher<SharedLink, Never> {
        sharedLinkSubject.eraseToAnyPublisher()
    }

    var linkModel: SharedLink {
        sharedLink
    }

    var editable: EditableData {
        return EditableData(expiration: linkModel.expirationDate, password: linkModel.customPassword)
    }

    func deleteSecureLink(completion: @escaping (Result<Void, Error>) -> Void) {
        let identifier = shareURL.identifier
        Task {
            do {
                try await repository.deletePublicLink(identifier)
                completion(.success)
            } catch {
                completion(.failure(error))
            }
        }
    }

    func updateSecureLink(values: UpdateShareURLDetails, completion: @escaping (Result<ShareURL, Error>) -> Void) {
        let identifier = shareURL.identifier
        let nodeIdentifier = node.identifier
        Task {
            do {
                try await repository.updatePublicLink(identifier, node: nodeIdentifier, with: values)
                try await self.handleSuccess(identifier: identifier, values: values, completion: completion)
            } catch {
                await self.handleError(error, completion: completion)
            }
        }
    }

    func getShareURL(publicLink: PublicLinkIdentifier) async throws -> ShareURL {
        let context = storage.mainContext

        return try await context.perform {
            guard let shareURL = ShareURL.fetch(id: publicLink.id, in: context) else {
                throw DriveError("Thre should be a Public link in store")
            }
            shareURL.clearCachedPassword()
            return shareURL
        }
    }

    @MainActor
    func handleSuccess(identifier: PublicLinkIdentifier, values: UpdateShareURLDetails, completion: @escaping (Result<ShareURL, Error>) -> Void) async throws {
        let shareURL = try await getShareURL(publicLink: identifier)
        self.sharedLink = self.sharedLink.updated(with: values, shareURL: shareURL)
        self.sharedLinkSubject.send(self.sharedLink)
        completion(.success(shareURL))
    }

    @MainActor
    func handleError(_ error: Error, completion: @escaping (Result<ShareURL, Error>) -> Void) {
        completion(.failure(error))
    }
}
