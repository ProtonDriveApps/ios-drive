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

public protocol SharedLinkRepository {
    func getSecureLink(for node: Node, completion: @escaping (Result<ShareURL, Error>) -> Void)
    func updateSecureLink(_ link: ShareURL, nodeIdentifier: NodeIdentifier, values: UpdateShareURLDetails, completion: @escaping (Result<ShareURL, Error>) -> Void)
    func deleteSecureLink(_ shareURL: ShareURL, shareID: String, completion: @escaping (Result<Void, Error>) -> Void)
}

extension Tower: SharedLinkRepository {
    public var didFetchAllShareURLs: Bool {
        get { storage.finishedFetchingShareURLs ?? false }
        set { storage.finishedFetchingShareURLs = newValue }
    }
    
    // MARK: - Retrieve or create
    public func getSecureLink(for node: Node, completion: @escaping (Result<ShareURL, Error>) -> Void) {
        sharingManager.getSecureLink(for: node) { result in
            completion(
                result.map { [unowned self] share -> ShareURL in
                    return self.moveToMainContext(share)
                }
            )
        }
    }

    public func updateSecureLink(_ link: ShareURL, nodeIdentifier: NodeIdentifier, values: UpdateShareURLDetails, completion: @escaping (Result<ShareURL, Error>) -> Void) {
        let moc = storage.backgroundContext
        moc.perform {
            let link = link.in(moc: moc)

            guard let email = link.share.root?.signatureEmail,
                  let address = self.sessionVault.getAddress(for: email) else {
                      return
                  }

            self.sharingManager.updateSecureLink(shareURL: link, node: nodeIdentifier, with: values, address: address, completion: completion)
        }
    }

    public func deleteSecureLink(_ shareURL: ShareURL, shareID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        sharingManager.deleteSecureLink(shareURL, shareID: shareID, completion: completion)
    }
}
