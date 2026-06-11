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
import PDContacts

public final class SharedWithMeLinksMetadataRetriever: SharedLinkRetriever {
    private let remoteShareDataSource: RemoteShareMetadataDataSource
    private let remoteLinksDataSource: RemoteLinksMetadataByVolumeDataSource
    private let sharedWithMeLinksCache: SharedWithMeMetadataCache
    private let contactsController: ContactsControllerProtocol
    private let keysVault: ForeignKeysVault

    public init(
        remoteShareDataSource: RemoteShareMetadataDataSource,
        remoteLinksDataSource: RemoteLinksMetadataByVolumeDataSource,
        sharedWithMeLinksCache: SharedWithMeMetadataCache,
        contactsController: ContactsControllerProtocol,
        keysVault: ForeignKeysVault
    ) {
        self.remoteShareDataSource = remoteShareDataSource
        self.remoteLinksDataSource = remoteLinksDataSource
        self.sharedWithMeLinksCache = sharedWithMeLinksCache
        self.contactsController = contactsController
        self.keysVault = keysVault
    }

    public func retrieve(dataSource: SharedLinkIdDataSource) async throws {
        let links = dataSource.getLinks()
        try await retrieve(links: links)
    }

    public func retrieve(links: [SharedWithMeLink]) async throws {
        guard !links.isEmpty else {
            Log.info("No shared links to process.", domain: .sharing)
            return
        }

        let sharedGroups = links.groupByVolume(maxSize: 50)
        var allEmails = Set<String>()

        for sharedGroup in sharedGroups {
            do {
                let links = try await self.cacheMetadata(for: sharedGroup)
                let emails = links.compactMap { $0.nameSignatureEmail }
                allEmails.formUnion(emails)
            } catch {
                Log.error("Failed to process shared group for volume \(sharedGroup.volumeId)", error: error, domain: .sharing)
            }
        }

        await synchronizeForeignPublicKeys(emails: allEmails)
    }

    private func synchronizeForeignPublicKeys(emails: Set<String>) async {
        let foreignKeys = await withTaskGroup(of: (String, [PublicKey]).self) { group in
            for email in emails {
                group.addTask {
                    let keys = try? await self.contactsController.fetchInternalPublicKeys(email: email)
                    let publicKeys = (keys ?? []).map(\.publicKey)
                    return (email.canonicalEmailForm, publicKeys)
                }
            }

            var foreignPublicKeys = [String: [PublicKey]]()
            // Collect all results from the task group
            for await item in group {
                foreignPublicKeys[item.0] = item.1
            }
            return foreignPublicKeys
        }
        await MainActor.run {
            keysVault.storeForeignPublicKeys(foreignKeys)
        }
    }

    private func cacheMetadata(for volumeGroup: VolumeGroup) async throws -> [Link] {
        let linkIds = volumeGroup.items.map(\.linkId)
        let items = volumeGroup.items
        let volumeId = volumeGroup.volumeId

        let linksResponse = try await self.remoteLinksDataSource.getMetadata(forLinks: linkIds, inVolume: volumeId)

        try await withThrowingTaskGroup(of: Void.self) { group in
            for item in items {
                group.addTask {
                    do {
                        if let linkResponse = linksResponse.links.first(where: { $0.linkID == item.linkId }) {
                            let fetchedShare = try await self.remoteShareDataSource.getMetadata(forShare: item.shareId)
                            try await self.sharedWithMeLinksCache.cache(linkResponse, fetchedShare)
                        } else {
                            Log.error("Link response not found for linkID: \(item.linkId), shareID: \(item.shareId), volumeID: \(volumeId)", error: nil, domain: .sharing)
                        }
                    } catch {
                        Log.error("Failed to process link ID \(item.linkId)", error: error, domain: .sharing)
                    }
                }
            }
            try await group.waitForAll()
        }

        return linksResponse.links
    }
}

private struct VolumeGroup {
    let volumeId: String
    let items: [SharedItem]
}

private struct SharedItem {
    let linkId: String
    let shareId: String
}

extension Array where Element == SharedWithMeLink {
    fileprivate func groupByVolume(maxSize size: Int) -> [VolumeGroup] {
        var groupedLinks: [String: [SharedWithMeLink]] = [:]

        // Group links by volumeId
        for link in self {
            groupedLinks[link.volumeId, default: []].append(link)
        }

        // Create VolumeGroup objects with the specified size
        var result: [VolumeGroup] = []
        for (volumeId, links) in groupedLinks {
            var currentGroupItems: [SharedItem] = []

            for link in links {
                let item = SharedItem(linkId: link.linkId, shareId: link.shareId)
                currentGroupItems.append(item)

                if currentGroupItems.count == size {
                    result.append(VolumeGroup(volumeId: volumeId, items: currentGroupItems))
                    currentGroupItems = []
                }
            }

            // Add remaining items if any
            if !currentGroupItems.isEmpty {
                result.append(VolumeGroup(volumeId: volumeId, items: currentGroupItems))
            }
        }

        return result
    }
}
