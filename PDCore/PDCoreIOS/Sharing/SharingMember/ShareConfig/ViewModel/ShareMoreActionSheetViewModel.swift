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
import PDLocalization

final class ShareMoreActionSheetViewModel: ObservableObject {
    private let dependencies: Dependencies
    let actionTitle = Localization.share_action_stop_sharing
    let actionSubtitle = Localization.share_action_stop_sharing_desc
    @Published var isDeleting = false
    
    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }
    
    func stopSharing() {
        isDeleting = true
        guard let shareID = dependencies.shareMetadataProvider.shareID else {
            isDeleting = false
            dependencies.coordinator.didStopSharing()
            return
        }
        Task {
            do {
                try await dependencies.sharedLinkRepository.deleteShare(shareID, force: true)
                await MainActor.run {
                    isDeleting = false
                    dependencies.coordinator.didStopSharing()
                }
            } catch {
                await MainActor.run {
                    isDeleting = false
                    dependencies.messageHandler.handleError(PlainMessageError(error.localizedDescription))
                }
            }
        }
    }
}

extension ShareMoreActionSheetViewModel {
    struct Dependencies {
        let coordinator: SharingMemberCoordinatorProtocol
        let messageHandler: UserMessageHandlerProtocol
        let sharedLinkRepository: SharedLinkRepository
        let shareMetadataProvider: ShareMetadataProvider
    }
}
