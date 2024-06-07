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

    init(
        node: Node,
        sharedLinkSubject: CurrentValueSubject<SharedLink, Never>,
        shareURL: ShareURL,
        repository: SharedLinkRepository
    ) {
        self.node = node
        self.shareURL = shareURL
        self.repository = repository
        self.sharedLinkSubject = sharedLinkSubject
        self.sharedLink = sharedLinkSubject.value
        self.shareURLID = sharedLinkSubject.value.id
        self.shareID = sharedLinkSubject.value.shareID

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
        repository.deleteSecureLink(shareURL, shareID: node.shareID, completion: completion)
    }

    func updateSecureLink(values: UpdateShareURLDetails, completion: @escaping (Result<ShareURL, Error>) -> Void) {
        repository.updateSecureLink(
            shareURL,
            nodeIdentifier: node.identifier,
            values: values
        ) { [weak self] result in
            guard let self = self else  { return }
            if case let .success(shareURL) = result {
                self.sharedLink = self.sharedLink.updated(with: values, shareURL: shareURL)
                self.sharedLinkSubject.send(self.sharedLink)
            }
            completion(result)
        }
    }
}
