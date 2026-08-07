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

import Combine
import Foundation
import PDClient
import PDCore
import PDLocalization
import PDUIComponents
import UIKit

protocol InvitationSuccessHandler {
    func append(newInvitee: [InviteeInfo])
}

protocol InviteeConfigSheetViewModel: AnyObject {
    func update(permission: AccessPermission, for invitee: InviteeInfo)
    func resendInvitationMail(to invitee: InviteeInfo)
    func copyInvitationLink(invitee: InviteeInfo)
    func removeAccess(of invitee: InviteeInfo)
}

final class InviteeViewModel: ObservableObject {
    private var cancellables = Set<AnyCancellable>()
    private let dependencies: Dependencies
    
    @Published private(set) var isFetchingList = true
    @Published private(set) var inviteeList: [InviteeInfo] = []
    @Published private(set) var allowEditorsToManageSharing = false
    @Published private(set) var isUpdatingEditorAccess = false
    /// Confirmation shown before a destructive/irreversible change (e.g. downgrading your own access).
    @Published var confirmationDialog: DialogSheetModel?
    /// [Email: Name]
    @Published private var nameDictionary: [String: String] = [:]
    /// Set when the owner dismisses the one-time editor-permissions tooltip; kept in sync with the store.
    @Published private var didDismissAdminSharingTooltip = false
    @Published private(set) var owner: LinkOwner?
    let inviteButtonTitle = Localization.sharing_member_invite_button
    let sectionHeader = Localization.sharing_member_invitee_section_header

    var hasSharingEditing: Bool {
        dependencies.nodeSharingPolicy.canManageSharing(
            editorsCanShare: dependencies.shareMetadataController.editorsCanShare
        )
    }

    /// Visibility and copy for the "editor access" settings section (owner-only, admin-permissions flag on).
    ///
    /// Restricted to `.common` shares: the backend doesn't support the admin-permissions feature
    /// (of which "editors can manage sharing" is part) for photos/albums, so the toggle is hidden there —
    /// matching the owner-only gating on the album share entry points.
    var editorAccessSetting: EditorAccessSetting {
        EditorAccessSetting(
            isVisible: dependencies.nodeSharingPolicy.isOwner
                && dependencies.featureFlagsController.hasSharingAdminPermissions
                && dependencies.sharingType == .common,
            sectionTitle: Localization.sharing_member_access_section_title,
            toggleTitle: Localization.sharing_member_allow_editors_to_manage_sharing
        )
    }

    /// Stopping sharing deletes the share for everyone, so it is an owner-only capability.
    var canStopSharing: Bool {
        dependencies.nodeSharingPolicy.isOwner
    }

    /// Whether the "more" action sheet has anything to show — the owner-only editor-access setting or
    /// stop sharing. The gear entry point is hidden otherwise (e.g. an editor, even one who can share).
    var canOpenMoreActions: Bool {
        editorAccessSetting.isVisible || canStopSharing
    }

    var adminSharingTooltip: AdminSharingTooltip? {
        guard editorAccessSetting.isVisible,
              dependencies.shareMetadataController.editorsCanShare,
              inviteeList.contains(where: { $0.permissions.isEditor }),
              !didDismissAdminSharingTooltip
        else {
            return nil
        }
        return AdminSharingTooltip(
            title: Localization.sharing_member_editor_permissions_tooltip_title,
            message: Localization.sharing_member_editor_permissions_tooltip_message
        )
    }

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
        self.didDismissAdminSharingTooltip = dependencies.adminSharingTooltipStore.hasSeenAdminSharingTooltip
        subscribeForUpdate()
    }

    /// Resolves the owner row. Prefers the link's `OwnedBy`; when that isn't available but we already know
    /// the current user owns the item, shows them (scoped to owners so a non-owner admin is never
    /// mislabeled as the owner).
    private func getOwner() -> LinkOwner? {
        if let owner = dependencies.sharingIdentityResource.loadOwner() {
            return owner
        }
        guard dependencies.nodeSharingPolicy.isOwner else { return nil }
        return dependencies.sharingIdentityResource.loadCurrentUserAsOwner()
    }

    func getName(for email: String) -> String? {
        let name = nameDictionary[email]
        if let name {
            return name.isEmpty ? nil : name
        } else {
            Task { await queryName(of: [email]) }
            return nil
        }
    }

    /// Display name for a member/owner row. For the current user it uses their account name and adds
    /// a "(you)" suffix; for everyone else it's the contact name (or `nil`, falling back to the email).
    private func getDisplayName(for email: String, isCurrentUser: Bool) -> String? {
        guard isCurrentUser else { return getName(for: email) }
        let base = dependencies.sharingIdentityResource.currentUserName ?? getName(for: email) ?? email
        return Localization.sharing_member_current_user_suffix(name: base)
    }
    
    /// - Returns: (Title, Subtitle)
    func info(of invitee: InviteeInfo) -> InviteeCellRenderData {
        if invitee.externalInvitationState == .pending {
            return InviteeCellRenderData(
                name: nil,
                mail: invitee.inviteeEmail,
                status: Localization.sharing_member_pending,
                statusAccessibilityIdentifier: "Pending"
            )
        }
        
        let canEdit = Localization.sharing_member_permission_can_edit
        let canView = Localization.sharing_member_permission_can_view
        let status: String
        let statusAccessibilityIdentifier: String
        if invitee.permissions.isEditor {
            status = canEdit
            statusAccessibilityIdentifier = "editor"
        } else {
            status = canView
            statusAccessibilityIdentifier = "viewer"
        }
        return InviteeCellRenderData(
            name: getDisplayName(for: invitee.inviteeEmail, isCurrentUser: isCurrentUser(invitee)),
            mail: invitee.inviteeEmail,
            status: status,
            statusAccessibilityIdentifier: statusAccessibilityIdentifier
        )
    }
    
    /// Maps the owner domain object to the shared cell render data, so the owner renders through the
    /// same structure as invitees. The name line becomes "Alice (you)" for the current user.
    func info(of owner: LinkOwner) -> InviteeCellRenderData {
        return InviteeCellRenderData(
            name: getDisplayName(for: owner.email, isCurrentUser: owner.isCurrentUser),
            mail: owner.email,
            status: Localization.sharing_member_role_owner,
            statusAccessibilityIdentifier: "owner"
        )
    }

    func clickInviteButton() {
        dependencies.coordinator.openInviteView(
            initializedPublisher: dependencies.initializedPublisher,
            invitationSuccessHandler: self,
            invitedMails: Set(inviteeList.map(\.inviteeEmail))
        )
    }

    func dismissAdminSharingTooltip() {
        dependencies.adminSharingTooltipStore.hasSeenAdminSharingTooltip = true
        didDismissAdminSharingTooltip = true
    }

    func setAllowEditorsToManageSharing(_ enabled: Bool) {
        guard enabled != allowEditorsToManageSharing else { return }
        guard let shareID = dependencies.shareMetadataController.shareID else { return }
        let previousValue = allowEditorsToManageSharing
        allowEditorsToManageSharing = enabled
        isUpdatingEditorAccess = true
        Task {
            do {
                try await dependencies.shareEditorsCanShareInteractor.update(editorsCanShare: enabled, shareID: shareID)
                await MainActor.run {
                    dependencies.shareMetadataController.setEditorsCanShare(enabled)
                    isUpdatingEditorAccess = false
                    dependencies.messageHandler.handleSuccess(
                        enabled
                            ? Localization.sharing_member_editors_can_share_enabled
                            : Localization.sharing_member_editors_can_share_disabled
                    )
                }
            } catch {
                await MainActor.run {
                    allowEditorsToManageSharing = previousValue
                    isUpdatingEditorAccess = false
                    show(error: error, action: #function)
                }
            }
        }
    }
}

// MARK: - Private functions
extension InviteeViewModel {
    private func subscribeForUpdate() {
        dependencies.inviteeListLoadingInteractor.result
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                self?.handleInviteeLoadResult(result)
            }
            .store(in: &cancellables)
        dependencies.initializedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isInitialized in
                guard isInitialized else { return }
                self?.fetchInviteeList()
            }
            .store(in: &cancellables)
        
        dependencies.shareMetadataController.updatePublisher
            .sink { [weak self] in
                guard let self else { return }
                self.allowEditorsToManageSharing = self.dependencies.shareMetadataController.editorsCanShare
                self.owner = self.getOwner()
            }
            .store(in: &cancellables)
        
        $inviteeList.sink { [weak self] inviteeList in
            self?.inviteeListIsChanged(inviteeList: inviteeList)
        }
        .store(in: &cancellables)
    }

    private func fetchInviteeList() {
        guard let shareID = dependencies.shareMetadataController.shareID else {
            isFetchingList = false
            return
        }
        isFetchingList = true
        dependencies.inviteeListLoadingInteractor.execute(with: shareID)
    }
    
    private func handleInviteeLoadResult(_ result: Result<[InviteeInfo], Error>) {
        switch result {
        case .success(let list):
            self.inviteeList = list
            dependencies.sharingConfigUpdater.update(hasInvitee: !list.isEmpty)
        case .failure(let error):
            Log.error("Load invitee list failed", error: error, domain: .sharing)
            let displayError = InvitationErrorMappingPolicy().map(error: error)
            dependencies.messageHandler.handleError(displayError)
        }
        self.isFetchingList = false
    }

    private func queryName(of emails: [String]) async {
        let remoteDic = await withTaskGroup(
            of: (String, String?).self,
            returning: [String: String].self
        ) { group in
            for email in emails {
                group.addTask {
                    let name = await self.dependencies.contactsController.name(of: email)
                    return (email, name)
                }
            }
            var remoteDic: [String: String] = [:]
            for await result in group {
                remoteDic[result.0] = result.1 ?? ""
            }
            return remoteDic
        }
        await MainActor.run { self.nameDictionary.merge(remoteDic, uniquingKeysWith: { $1 }) }
    }

    private func inviteeListIsChanged(inviteeList: [any InviteeInfo]) {
        let wrapperList = inviteeList.map { invitee -> InvitationInfoWrapper in
            let name = getName(for: invitee.inviteeEmail)
            return .init(id: invitee.invitationID, name: name ?? invitee.inviteeEmail)
        }
        dependencies.invitationResultController?.inviteeListHasUpdated(to: wrapperList)
    }
}

extension InviteeViewModel: InvitationSuccessHandler {
    func append(newInvitee: [InviteeInfo]) {
        assert(Thread.isMainThread)
        inviteeList.append(contentsOf: newInvitee)
        dependencies.sharingConfigUpdater.update(hasInvitee: true)
    }
}

extension InviteeViewModel: InviteeConfigSheetViewModel {
    func presentConfigSheet(for invitee: InviteeInfo, name: String?) {
        dependencies.coordinator.presentInviteeConfigSheet(
            for: invitee,
            inviteeName: name,
            inviterPermissions: getInviterPermissions(),
            handler: self
        )
    }
    
    func update(permission: AccessPermission, for invitee: InviteeInfo) {
        let cappedPermission = permission.capped(to: getInviterPermissions())
        if cappedPermission == invitee.permissions { return }
        // Downgrading your own access to viewer means losing your ability to manage sharing and edit,
        // so confirm first. Changes to other members apply immediately.
        let isDowngradingOwnAccessToViewer = cappedPermission.isViewer && isCurrentUser(invitee)
        if isDowngradingOwnAccessToViewer {
            confirmationDialog = DialogSheetModel(
                title: Localization.sharing_member_change_own_access_message(name: dependencies.shareMetadataController.itemName),
                buttons: [
                    DialogButton(
                        title: Localization.sharing_member_change_own_access_confirmation,
                        role: .destructive
                    ) { [weak self] in
                        self?.applyUpdate(permission: cappedPermission, for: invitee, downgradingOwnAccess: true)
                    }
                ],
                header: Localization.sharing_member_change_own_access_title
            )
            return
        }
        applyUpdate(permission: cappedPermission, for: invitee, downgradingOwnAccess: false)
    }

    private func applyUpdate(permission: AccessPermission, for invitee: InviteeInfo, downgradingOwnAccess: Bool) {
        guard let shareID = dependencies.shareMetadataController.shareID else { return }
        Task {
            do {
                let newInfo = try await dependencies.inviteeActionHandler.update(
                    permission: permission,
                    for: invitee,
                    shareID: shareID
                )
                if downgradingOwnAccess {
                    // The user gave up our own sharing-management access. Refresh the share so the local
                    // node role reflects "viewer" and dismiss.
                    _ = try? await dependencies.shareMetadataController.fetchShareMetaData()
                    await MainActor.run {
                        // Show the confirmation once the config screen is gone; a banner posted while the
                        // full-screen modal is up would render behind it and never be seen. Capture the
                        // message handler directly since this view model is torn down with the screen.
                        let messageHandler = dependencies.messageHandler
                        dependencies.coordinator.dismissSharingConfiguration {
                            messageHandler.handleSuccess(Localization.sharing_member_access_updated)
                        }
                    }
                    return
                }
                await MainActor.run {
                    guard let index = inviteeList.firstIndex(where: { $0.invitationID == invitee.invitationID }) else {
                        return
                    }
                    inviteeList[index] = newInfo
                    dependencies.messageHandler.handleSuccess(Localization.sharing_member_access_updated)
                }
            } catch {
                show(error: error, action: #function)
            }
        }
    }

    private func isCurrentUser(_ invitee: InviteeInfo) -> Bool {
        dependencies.sharingIdentityResource.isCurrentUser(email: invitee.inviteeEmail)
    }
    
    private func getInviterPermissions() -> AccessPermission {
        dependencies.nodeSharingPolicy.getInviterPermissions()
    }
    
    func resendInvitationMail(to invitee: InviteeInfo) {
        guard let shareID = dependencies.shareMetadataController.shareID else { return }
        Task {
            do {
                try await dependencies.inviteeActionHandler.resendInvitations(to: invitee, shareID: shareID)
                dependencies.messageHandler.handleSuccess(Localization.sharing_member_resend_invitation)
            } catch {
                show(error: error, action: #function)
            }
        }
    }
    
    func copyInvitationLink(invitee: InviteeInfo) {
        Task {
            do {
                let share = try await dependencies.shareMetadataController.getDirectShare().share
                guard
                    let url = try await dependencies.inviteeActionHandler.copyInvitationLink(
                        invitation: invitee,
                        volumeID: share.volumeID,
                        linkID: share.linkID
                    )
                else {
                    return
                }
                dependencies.pasteboardWrapper.string = url
                dependencies.messageHandler.handleSuccess(Localization.sharing_member_invite_link_copied)
            } catch {
                show(error: error, action: #function)
            }
        }
    }
    
    func removeAccess(of invitee: InviteeInfo) {
        guard let shareID = dependencies.shareMetadataController.shareID else { return }
        let isLastAccess = inviteeList.count == 1
        Task {
            do {
                try await dependencies.inviteeActionHandler.removeAccess(of: invitee, shareID: shareID, isLast: isLastAccess)
                await MainActor.run {
                    inviteeList.removeAll(where: { $0.invitationID == invitee.invitationID })
                    dependencies.messageHandler.handleSuccess(Localization.sharing_member_access_removed)
                    dependencies.sharingConfigUpdater.update(hasInvitee: !inviteeList.isEmpty)
                }
            } catch {
                show(error: error, action: #function)
            }
        }
    }
    
    private func show(error: Error, action: String) {
        if let invitationError = error as? InvitationErrors, invitationError == .unexpectedData {
            assert(false, "Unexpected parameters for api call")
            return
        }
        Log.error("\(action) failed", error: error, domain: .sharing)
        let displayError = InvitationErrorMappingPolicy().map(error: error)
        dependencies.messageHandler.handleError(displayError)
    }

}

extension InviteeViewModel {
    struct Dependencies {
        let contactsController: ContactsControllerProtocol
        let coordinator: SharingMemberCoordinatorProtocol
        let featureFlagsController: FeatureFlagsControllerProtocol
        let initializedPublisher: AnyPublisher<Bool, Never>
        let inviteeActionHandler: InviteeActionHandler
        let inviteeListLoadingInteractor: InviteeListLoadInteractor
        let invitationResultController: InvitationResultControllerProtocol?
        let messageHandler: UserMessageHandlerProtocol
        let pasteboardWrapper: PasteboardWrapper
        let shareMetadataController: ShareMetadataProvider
        let sharingConfigUpdater: SharingConfigUpdater
        let nodeSharingPolicy: NodeSharingPolicy
        let sharingIdentityResource: SharingIdentityResource
        let shareEditorsCanShareInteractor: ShareEditorsCanShareInteractorProtocol
        let sharingType: SharingConfigType
        let adminSharingTooltipStore: AdminSharingTooltipStore

        init(
            contactsController: ContactsControllerProtocol,
            coordinator: SharingMemberCoordinatorProtocol,
            featureFlagsController: FeatureFlagsControllerProtocol,
            initializedPublisher: AnyPublisher<Bool, Never>,
            inviteeActionHandler: InviteeActionHandler,
            inviteeListLoadingInteractor: InviteeListLoadInteractor,
            invitationResultController: InvitationResultControllerProtocol?,
            messageHandler: UserMessageHandlerProtocol,
            shareMetadataController: ShareMetadataProvider,
            sharingConfigUpdater: SharingConfigUpdater,
            pasteboardWrapper: PasteboardWrapper = .init(),
            nodeSharingPolicy: NodeSharingPolicy,
            sharingIdentityResource: SharingIdentityResource,
            shareEditorsCanShareInteractor: ShareEditorsCanShareInteractorProtocol,
            sharingType: SharingConfigType,
            adminSharingTooltipStore: AdminSharingTooltipStore
        ) {
            self.contactsController = contactsController
            self.coordinator = coordinator
            self.featureFlagsController = featureFlagsController
            self.initializedPublisher = initializedPublisher
            self.inviteeActionHandler = inviteeActionHandler
            self.inviteeListLoadingInteractor = inviteeListLoadingInteractor
            self.invitationResultController = invitationResultController
            self.messageHandler = messageHandler
            self.shareMetadataController = shareMetadataController
            self.sharingConfigUpdater = sharingConfigUpdater
            self.pasteboardWrapper = pasteboardWrapper
            self.nodeSharingPolicy = nodeSharingPolicy
            self.sharingIdentityResource = sharingIdentityResource
            self.shareEditorsCanShareInteractor = shareEditorsCanShareInteractor
            self.sharingType = sharingType
            self.adminSharingTooltipStore = adminSharingTooltipStore
        }
    }

    struct InviteeCellRenderData {
        let name: String?
        let mail: String
        let status: String
        let statusAccessibilityIdentifier: String
    }

    struct EditorAccessSetting {
        let isVisible: Bool
        let sectionTitle: String
        let toggleTitle: String
    }

    struct AdminSharingTooltip {
        let title: String
        let message: String
    }
}
