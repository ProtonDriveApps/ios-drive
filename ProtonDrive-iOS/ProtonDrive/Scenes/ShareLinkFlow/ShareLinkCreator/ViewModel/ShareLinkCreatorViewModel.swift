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

final class ShareLinkCreatorViewModel {
    var onErrorSharing: (() -> Void)?
    var onSharedLinkObtained: ((ShareURL) -> Void)?

    private let node: Node
    private let sharedLinkRepository: SharedLinkRepository

    init(
        node: Node,
        sharedLinkRepository: SharedLinkRepository
    ) {
        self.node = node
        self.sharedLinkRepository = sharedLinkRepository
    }

    var title: String {
        "Share via link"
    }

    var loadingMessage: String {
        "Preparing secure link"
    }

    func getSharedLink() {
        sharedLinkRepository.getSecureLink(for: node) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let link):
                self.onSharedLinkObtained?(link)

            case .failure(let error):
                NotificationCenter.default.postBanner(.failure(error, delay: .delayed))
                self.onErrorSharing?()
            }
        }
    }
}
