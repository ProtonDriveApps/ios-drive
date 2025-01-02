// Copyright (c) 2024 Proton AG
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
import PDClient
import PDCore

protocol ShareMetadataProvider {
    var itemName: String { get }
    var shareID: String { get }
    /// Public link is enabled
    var isShared: Bool { get }
    var nodeIdentifier: NodeIdentifier { get }

    func getShareLink() throws -> SharedLink?
    func getShare() async throws -> PDClient.Share
    func updateMetadata() async throws
}

/// Share metadata provider
final class ShareMetadataController: ShareMetadataProvider {
    let itemName: String
    private(set) var nodeIdentifier: NodeIdentifier = .init("", "", "")
    private let client: ShareMemberAPIClient
    private let shareCreator: ShareCreatorProtocol
    private let node: Node
    private var share: PDClient.Share?
    var isShared: Bool { node.isShared }
    
    init(client: ShareMemberAPIClient, shareCreator: ShareCreatorProtocol, node: Node) {
        self.client = client
        self.shareCreator = shareCreator
        self.node = node
        self.itemName = node.decryptedName
        node.managedObjectContext?.performAndWait {
            self.nodeIdentifier = node.identifier
        }
    }
    
    func getShareLink() throws -> SharedLink? {
        let shareURLObj = node.managedObjectContext?.performAndWait {
            node.directShares.first?.shareUrls.first
        }
        guard let shareURLObj else { return nil }
        return try SharedLink(shareURL: shareURLObj)
    }
    
    var shareID: String {
        node.managedObjectContext?.performAndWait {
            node.directShares.first?.id
        } ?? ""
    }
    
    func getShare() async throws -> PDClient.Share {
        if let share {
            return share
        } 
        
        do {
            try await updateMetadata()
            return try await getShare()
        } catch {
            let newShare = try await createShare()
            share = newShare
            return newShare
        }
    }
    
    func updateMetadata() async throws {
        share = try await fetchMetadata()
    }
    
    private func createShare() async throws -> PDClient.Share {
        _ = try await shareCreator.createShare(for: node)
        return try await fetchMetadata()
    }
    
    private func fetchMetadata() async throws -> PDClient.Share {
        if shareID.isEmpty { throw ShareMetadataErrors.shareIDIsMissing }
        return try await client.getShare(shareID)
    }
}

extension ShareMetadataController {
    enum ShareMetadataErrors: Error {
        case shareIDIsMissing
    }
}
