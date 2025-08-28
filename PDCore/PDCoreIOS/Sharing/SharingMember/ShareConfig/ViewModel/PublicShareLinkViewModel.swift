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

import CoreData
import Combine
import Foundation
import PDClient
import PDCore
import PDLocalization

final class PublicShareLinkViewModel: ObservableObject {
    @Published private(set) var isLoading = true
    @Published private(set) var hasLink = false
    @Published private(set) var linkPermission: AccessPermission = [.read]
    let canEditText = Localization.sharing_member_permission_can_edit
    let canViewText = Localization.sharing_member_permission_can_view
    let componentTitle = Localization.sharing_member_anyone_with_link
    let copyLinkTitle = Localization.share_action_copy_link
    let sectionHeader = Localization.sharing_member_public_link_header
    let settingButtonTitle = Localization.share_action_link_settings
    let stopSharingAlertMessage = Localization.share_stop_sharing_alert_message
    let stopSharingAlertTitle = Localization.share_stop_sharing
    private let dependencies: Dependencies
    private var cancellables = Set<AnyCancellable>()
    private var linkIdentifier: PublicLinkIdentifier?
    
    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }
    
    var canEditPermission: Bool {
        return dependencies.featureFlagsController.hasPublicShareEditMode
    }
    
    var shouldDisableUpdatePermission: Bool {
        isLoading || !hasLink
    }
    
    var componentSubtitle: String {
        linkPermission.isEditor ? canEditText : canViewText
    }
    
    func update(linkPermission: AccessPermission) {
        if self.linkPermission == linkPermission { return }
        let oldPermission = self.linkPermission
        self.linkPermission = linkPermission
        updateShareURLPermission(newPermission: linkPermission, oldPermission: oldPermission)
    }
    
    func openSettingPage() {
        do {
            guard let sharedLink = try dependencies.shareMetadataProvider.getShareLink() else { return }
            dependencies.coordinator.openLinkSettingView(sharedLink: sharedLink)
        } catch {
            handle(error: error)
        }
    }
    
    func prepareSharedLink() {
        guard dependencies.shareMetadataProvider.isPublicLinkEnabled else {
            isLoading = false
            return
        }
        let nodeIdentifier = dependencies.shareMetadataProvider.nodeIdentifier
        let permission = canEditPermission ? linkPermission : .read
        Task {
            do {
                linkIdentifier = try await dependencies.sharedLinkRepository.getPublicLink(
                    for: nodeIdentifier, 
                    permissions: permission.toRequestPermission()
                )
                await setupPermission(linkIdentifier: linkIdentifier)
                await MainActor.run {
                    isLoading = false
                    hasLink = true
                    dependencies.sharingConfigUpdater.update(hasPublicLink: true)
                }
            } catch {
                handle(error: error)
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
    
    func prepareLink() -> String? {
        do {
            let shareLink = try dependencies.shareMetadataProvider.getShareLink()
            return shareLink?.link
        } catch {
            handle(error: error)
            return nil
        }
    }
    
    func createLink() {
        isLoading = true
        let nodeIdentifier = dependencies.shareMetadataProvider.nodeIdentifier
        let permission = canEditPermission ? linkPermission : .read
        Task {
            do {
                linkIdentifier = try await dependencies.sharedLinkRepository.getPublicLink(
                    for: nodeIdentifier,
                    permissions: permission.toRequestPermission()
                )
                await MainActor.run {
                    hasLink = true
                    isLoading = false
                    dependencies.messageHandler.handleSuccess(Localization.sharing_member_link_created)
                    dependencies.sharingConfigUpdater.update(hasPublicLink: true)
                }
            } catch {
                handle(error: error)
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
    
    func deleteLink() {
        isLoading = true
        do {
            let identifier = try getPublicLinkIdentifier()
            Task {
                do {
                    try await dependencies.sharedLinkRepository.deletePublicLink(identifier)
                    await MainActor.run {
                        hasLink = false
                        isLoading = false
                        linkPermission = .read
                        dependencies.sharingConfigUpdater.update(hasPublicLink: false)
                    }
                } catch {
                    handle(error: error)
                    await MainActor.run {
                        isLoading = false
                    }
                }
            }
        } catch {
            handle(error: error)
            isLoading = false
        }
    }
    
    func presentCopiedLinkBanner() {
        dependencies.messageHandler.handleSuccess(Localization.general_link_copied)
    }
}

extension PublicShareLinkViewModel {    
    private func getPublicLinkIdentifier() throws -> PublicLinkIdentifier {
        if let linkIdentifier {
            return linkIdentifier
        } else {
            guard let shareLink = try dependencies.shareMetadataProvider.getShareLink() else {
                throw InvitationErrors.unexpectedData
            }
            return shareLink.publicLinkIdentifier
        }
    }
    
    private func handle(error: Error) {
        dependencies.messageHandler.handleError(PlainMessageError(error.localizedDescription))
    }
    
    private func setupPermission(linkIdentifier: PublicLinkIdentifier?) async {
        guard let id = linkIdentifier?.id else { return }
        let rawPermission = await dependencies.context.perform { [weak self] in
            guard
                let self,
                let shareURL = PDCore.ShareURL.fetch(id: id, in: self.dependencies.context)
            else { return AccessPermission.read.rawValue }
            return shareURL.permissions.rawValue
        }
        await MainActor.run {
            linkPermission = .init(rawValue: rawPermission)
        }
    }
    
    private func updateShareURLPermission(newPermission: AccessPermission, oldPermission: AccessPermission) {
        guard let linkIdentifier else { return }
        self.isLoading = true
        let permissionStatus: UpdateShareURLDetails.Permissions = newPermission.isEditor ? .readAndWrite : .read
        Task {
            do {
                try await self.dependencies.sharedLinkRepository.updatePublicLink(
                    linkIdentifier,
                    with: .init(password: .unchanged, duration: .unchanged, permission: permissionStatus)
                )
                await MainActor.run {
                    self.isLoading = false
                }
            } catch {
                if let responseCode = error.responseCode, responseCode == 200004 {
                    let localizationError = PlainMessageError(Localization.share_max_editable_share_limit_error)
                    self.dependencies.messageHandler.handleError(localizationError)
                } else {
                    self.dependencies.messageHandler.handleError(PlainMessageError(error.localizedDescription))
                }
                await MainActor.run {
                    self.isLoading = false
                    let oldPermission: AccessPermission = oldPermission
                    self.linkPermission = oldPermission
                }
            }
        }
    }
    
#if DEBUG
    // For unit test
    func update(isLoading: Bool? = nil, hasLink: Bool? = nil, linkPermission: AccessPermission? = nil) {
        if let isLoading {
            self.isLoading = isLoading
        }
        if let hasLink {
            self.hasLink = hasLink
        }
        if let linkPermission {
            self.linkPermission = linkPermission
        }
    }
#endif
}

extension PublicShareLinkViewModel {
    struct Dependencies {
        let context: NSManagedObjectContext
        let coordinator: SharingMemberCoordinatorProtocol
        let featureFlagsController: FeatureFlagsControllerProtocol
        let messageHandler: UserMessageHandlerProtocol
        let sharedLinkRepository: SharedLinkRepository
        let shareMetadataProvider: ShareMetadataProvider
        let sharingConfigUpdater: SharingConfigUpdater
    }
}
