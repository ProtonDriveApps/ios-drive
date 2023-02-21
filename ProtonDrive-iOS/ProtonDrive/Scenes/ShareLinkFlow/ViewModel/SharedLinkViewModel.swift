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

import Combine
import Foundation

class SharedLinkViewModel: ObservableObject {
    private let link: SharedLink
    private let model: ShareLinkModel
    private let onCopyToClipboard: (String?) -> Void
    private let sharedLinkSubject: CurrentValueSubject<SharedLink, Never>
    private var cancellables = Set<AnyCancellable>()

    @Published var state: SharingLinkViewState
    @Published var shareLink = false
    @Published var attemptDeleteLink = false
    @Published var isScreenClosed = false

    init(
        model: ShareLinkModel,
        sharedLinkSubject: CurrentValueSubject<SharedLink, Never>,
        onCopyToClipboard:  @escaping (String?) -> Void
    ) {
        self.link = model.linkModel
        self.sharedLinkSubject = sharedLinkSubject
        self.onCopyToClipboard = onCopyToClipboard
        self.model = model

        let mapper = SharedLinkMapper()
        self.state = mapper.map(link, model.name)

        sharedLinkSubject.sink { [unowned self] in
            self.state = mapper.map($0, model.name)
        }
        .store(in: &cancellables)
    }

    func perform(_ action: LinkActionsSection.ActionType) {
        switch action {
        case .copyLink:
            NotificationCenter.default.postBanner(.info("Link copied"))
            onCopyToClipboard(model.linkModel.link)
        case .copyPassword:
            NotificationCenter.default.postBanner(.info("Password copied"))
            onCopyToClipboard(model.linkModel.customPassword)
        case .share:
            shareLink = true
        case .delete:
            attemptDeleteLink = true
        }
    }

    var formattedLink: String {
        model.linkModel.link
    }

    var stopSharingAlertTitle: String {
        "Stop sharing"
    }

    var stopSharingAlertMessage: String {
        "This will delete the link and remove access to your file or folder for anyone with the link. You can’t undo this action."
    }

    var stopSharingButton: String {
        "Stop sharing"
    }

    func deleteLink() {
        model.deleteSecureLink { [weak self] result in
            self?.isScreenClosed = true

            switch result {
            case.success:
                NotificationCenter.default.postBanner(.success("Sharing removed", delay: .delayed))

            case .failure(let error):
                NotificationCenter.default.postBanner(.failure(error, delay: .delayed))
            }
        }
    }
}

struct SharedLinkMapper {
    func map(_ link: SharedLink, _ name: String) -> SharingLinkViewState {
        let defaultPasswordMessage = "Anyone with this link can access your file/folder "
        let customPasswordMessage = "Anyone with the link and password can access the file/folder "
        let message = link.isCustom ? customPasswordMessage : defaultPasswordMessage

        return SharingLinkViewState(
            detailSection: SharedLinkSection(
                title: "Link",
                link: link.link,
                formattedText: SharedLinkSection.FormattedText(
                    regular: message,
                    bold: name
                )
            ),
            actionsSection: actions(for: link)
        )
    }

    private func actions(for link: SharedLink) -> LinkActionsSection {
        if link.customPassword.isEmpty {
            return [.copyLink, .share, .delete]
        } else {
            return [.copyLink, .copyPassword, .share, .delete]
        }
    }
}
