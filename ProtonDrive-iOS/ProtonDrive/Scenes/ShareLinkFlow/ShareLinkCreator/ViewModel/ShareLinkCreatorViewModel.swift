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
import PDCore
import PDLocalization

final class ShareLinkCreatorViewModel {
    var onErrorSharing: (() -> Void)?
    var onSharedLinkObtained: ((ShareURL) -> Void)?

    private let node: NodeIdentifier
    private let sharedLinkRepository: SharedLinkRepository
    private let storage: StorageManager

    init(
        node: NodeIdentifier,
        sharedLinkRepository: SharedLinkRepository,
        storage: StorageManager
    ) {
        self.node = node
        self.storage = storage
        self.sharedLinkRepository = sharedLinkRepository
    }

    var title: String {
        Localization.edit_section_share_via_link
    }

    var loadingMessage: String {
        Localization.share_via_prepare_secure_link
    }

    func getSharedLink() {
        Task {
            do {
                let publicLink = try await sharedLinkRepository.getPublicLink(for: node, permissions: .read)
                try await handleSuccess(publicLink)
            } catch {
                await handleError(error)
            }
        }
    }

    @MainActor
    func handleSuccess(_ identifier: PublicLinkIdentifier) async throws {
        let context = storage.mainContext
        guard let shareURL = ShareURL.fetch(id: identifier.id, in: context) else {
            throw DriveError("Missing public link.")
        }
        self.onSharedLinkObtained?(shareURL)
    }

    @MainActor
    func handleError(_ error: Error) {
        NotificationCenter.default.postBanner(.failure(error, delay: .delayed))
        self.onErrorSharing?()
    }
}
