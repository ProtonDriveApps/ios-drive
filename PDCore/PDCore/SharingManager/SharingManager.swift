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

import PDClient
import ProtonCoreCryptoGoInterface
import Foundation
import CoreData

typealias ShareUrlMeta = PDClient.ShareURLMeta

public struct PublicLinkIdentifier: Equatable {
    public let id: String
    public let shareID: String
    public let volumeID: String

    public init(id: String, shareID: String, volumeID: String) {
        self.id = id
        self.shareID = shareID
        self.volumeID = volumeID
    }
}

public struct ShareIdentifier {
    public let id: String

    public init(id: String) {
        self.id = id
    }
}

public protocol SharedLinkRepository: PublicLinkProvider, PublicLinkUpdater, PublicLinkDeleter, ShareDeleter { }

public final class SharingManager: SharedLinkRepository {
    private let provider: PublicLinkProvider
    private let updater: PublicLinkUpdater
    private let deleter: PublicLinkDeleter
    private let shareDeleter: ShareDeleter

    public init(
        provider: PublicLinkProvider,
        updater: PublicLinkUpdater,
        deleter: PublicLinkDeleter,
        shareDeleter: ShareDeleter
    ) {
        self.provider = provider
        self.updater = updater
        self.deleter = deleter
        self.shareDeleter = shareDeleter
    }

    public func getPublicLink(
        for node: NodeIdentifier,
        permissions: ShareURLMeta.Permissions
    ) async throws -> PublicLinkIdentifier {
        try await provider.getPublicLink(for: node, permissions: permissions)
    }

    public func updatePublicLink(_ identifier: PublicLinkIdentifier, with details: UpdateShareURLDetails) async throws {
        try await updater.updatePublicLink(identifier, with: details)
    }

    public func deletePublicLink(_ identifier: PublicLinkIdentifier) async throws {
        try await deleter.deletePublicLink(identifier)
    }
    
    public func deleteShare(_ id: String, force: Bool) async throws {
        try await shareDeleter.deleteShare(id, force: force)
    }
}
