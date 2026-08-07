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
import PDContacts
import PDCore
import PDLocalization
import UIKit
import SwiftUI
import ProtonCoreUIFoundations

extension SharingConfigViewFactory {
    struct Dependencies {
        let baseHost: String
        let client: Client
        let contactsController: ContactsControllerProtocol
        let contactsManager: ContactsManagerProtocol
        let entitlementsManager: EntitlementsManagerProtocol
        let featureFlagsController: FeatureFlagsControllerProtocol
        let messageHandler: UserMessageHandlerProtocol
        let sessionVault: SessionVault
        let shareMetaController: ShareMetadataProvider
        let storage: StorageManager
        let localSettings: LocalSettings
        let node: Node
    }
}

struct SharingConfigViewFactory {
    private let dependencies: Dependencies
    
    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }
    
    func makeConfigView(
        coordinator: SharingMemberCoordinatorProtocol,
        sharingType: SharingConfigType,
        invitationResultController: InvitationResultControllerProtocol?
    ) -> UINavigationController {
        let viewModel = SharingConfigViewModel(
            dependencies: .init(
                coordinator: coordinator,
                contactsController: dependencies.contactsController,
                messageHandler: dependencies.messageHandler,
                shareMetadataProvider: dependencies.shareMetaController,
                featureFlagsController: dependencies.featureFlagsController,
                sharingPolicy: NodeSharingPolicy(
                    node: dependencies.node,
                    featureFlagsController: dependencies.featureFlagsController
                )
            ),
            sharingType: sharingType
        )
        
        let inviteeViewModel = makeInviteeViewModel(
            coordinator: coordinator,
            initializedPublisher: viewModel.initializedPublisher,
            sharingConfigUpdater: viewModel,
            invitationResultController: invitationResultController,
            sharingType: sharingType
        )
        let inviteeListView = InviteeListView(viewModel: inviteeViewModel)
        let publicShareLinkView = makePublicLinkView(coordinator: coordinator, sharingConfigUpdater: viewModel)

        let hosting = SharingConfigView(
            viewModel: viewModel,
            inviteeViewModel: inviteeViewModel,
            inviteeListView: inviteeListView,
            publicShareLinkView: publicShareLinkView
        ).embeddedInHostingController()

        hosting.title = Localization.share_action_share
        let nav = UINavigationController(rootViewController: hosting)
        nav.modalPresentationStyle = .fullScreen
        return nav
    }
    
    private func makeInviteeViewModel(
        coordinator: SharingMemberCoordinatorProtocol,
        initializedPublisher: AnyPublisher<Bool, Never>,
        sharingConfigUpdater: SharingConfigUpdater,
        invitationResultController: InvitationResultControllerProtocol?,
        sharingType: SharingConfigType
    ) -> InviteeViewModel {
        let actionInteractor = InviteeActionInteractor(
            client: dependencies.client,
            linkAssemblePolicy: InvitationLinkAssemblePolicy(baseHost: dependencies.baseHost),
            shareDeleter: RemoteCachingShareDeleter(client: dependencies.client, storage: dependencies.storage)
        )
        let interactor = RemoteInviteeListLoadInteractor(client: dependencies.client)
        let editorsCanShareUpdater = ShareEditorsCanShareInteractor(client: dependencies.client)
        return InviteeViewModel(
            dependencies: .init(
                contactsController: dependencies.contactsController,
                coordinator: coordinator,
                featureFlagsController: dependencies.featureFlagsController,
                initializedPublisher: initializedPublisher,
                inviteeActionHandler: actionInteractor,
                inviteeListLoadingInteractor: AsyncRemoteInviteeListLoadInteractor(interactor: interactor),
                invitationResultController: invitationResultController,
                messageHandler: dependencies.messageHandler,
                shareMetadataController: dependencies.shareMetaController,
                sharingConfigUpdater: sharingConfigUpdater,
                nodeSharingPolicy: NodeSharingPolicy(node: dependencies.node, featureFlagsController: dependencies.featureFlagsController),
                sharingIdentityResource: NodeSharingIdentityResource(node: dependencies.node, sessionVault: dependencies.sessionVault),
                shareEditorsCanShareInteractor: editorsCanShareUpdater,
                sharingType: sharingType,
                adminSharingTooltipStore: LocalSettingsAdminSharingTooltipStore(localSettings: dependencies.localSettings)
            )
        )
    }
    
    private func makePublicLinkView(
        coordinator: SharingMemberCoordinatorProtocol,
        sharingConfigUpdater: SharingConfigUpdater
    ) -> PublicShareLinkView {
        let viewModel = PublicShareLinkViewModel(
            dependencies: .init(
                context: dependencies.storage.backgroundContext,
                coordinator: coordinator, 
                featureFlagsController: dependencies.featureFlagsController,
                messageHandler: dependencies.messageHandler,
                sharedLinkRepository: makeSharedLinkRepository(),
                shareMetadataProvider: dependencies.shareMetaController,
                sharingConfigUpdater: sharingConfigUpdater
            )
        )
        
        let view = PublicShareLinkView(viewModel: viewModel)
        return view
    }
    
    private func makeSharedLinkRepository() -> SharedLinkRepository {
        let storage = dependencies.storage
        let sessionVault = dependencies.sessionVault
        let client = dependencies.client

        let shareCreator = ShareCreator(storage: storage, sessionVault: sessionVault, cloudShareCreator: client.createShare, signersKitFactory: sessionVault, moc: storage.backgroundContext)
        let publicLinkCreator = RemoteCachingPublicLinkCreator(client: client, storage: storage, signersKitFactory: sessionVault)
        let publicLinkProvider = RemoteCachingPublicLinkProvider(client: client, storage: storage, shareCreator: shareCreator, publicLinkCreator: publicLinkCreator)
        let publicLinkUpdater = RemoteCachingPublicLinkUpdater(client: client, storage: storage, signersKitFactory: sessionVault)
        let shareDeleter = RemoteCachingShareDeleter(client: client, storage: storage)
        let publicLinkDeleter = RemoteCachingPublicLinkDeleter(client: client, storage: storage, shareDeleter: shareDeleter)
        return SharingManager(provider: publicLinkProvider, updater: publicLinkUpdater, deleter: publicLinkDeleter, shareDeleter: shareDeleter)
    }
    
    func makeInvitationView(
        coordinator: SharingMemberCoordinatorProtocol,
        initializedPublisher: AnyPublisher<Bool, Never>,
        invitationSuccessHandler: InvitationSuccessHandler,
        invitedMails: Set<String>
    ) -> UINavigationController {
        let viewModel = InvitationViewModel(
            dependencies: .init(
                contactsQuerier: ContactsQueryInteractor(contactsController: dependencies.contactsController),
                coordinator: coordinator,
                featureFlagsController: dependencies.featureFlagsController,
                initializedPublisher: initializedPublisher,
                invitationUserHandler: makeInvitationInteractor(),
                invitationSuccessHandler: invitationSuccessHandler,
                messageHandler: dependencies.messageHandler,
                node: dependencies.node,
                sessionVault: dependencies.sessionVault,
                shareMetadataProvider: dependencies.shareMetaController,
                nodeSharingPolicy: NodeSharingPolicy(node: dependencies.node, featureFlagsController: dependencies.featureFlagsController)
            ),
            invitedMails: invitedMails
        )
        let hosting = InvitationView(viewModel: viewModel).embeddedInHostingController()
        hosting.title = Localization.share_action_share
        
        let nav = UINavigationController(rootViewController: hosting)
        nav.isModalInPresentation = true
        
        return nav
    }
    
    private func makeInvitationInteractor() -> InvitationInteractor {
        let internalUserHandler = InternalUserInviteInteractor(
            client: dependencies.client,
            encryptionResource: Encryptor()
        )
        
        let externalUserHandler = ExternalUserInviteInteractor(
            client: dependencies.client,
            encryptionResource: Encryptor()
        )
        
        return InvitationInteractor(
            contactsManager: dependencies.contactsManager,
            sessionDecryptor: SessionKeyDecryptor(),
            externalUserInviteHandler: externalUserHandler,
            internalUserInviteHandler: internalUserHandler
        )
    }
    
    func makeActionSheet(
        for group: ContactQueryResult,
        handler: InvitationSheetHandler
    ) -> PMActionSheet {
        let itemGroup = makeGroupActionItems(for: group)
        
        var sheet: PMActionSheet!
        let header = PMActionSheetHeaderView(
            title: group.name,
            leftItem: .right(IconProvider.cross),
            rightItem: .left(Localization.general_apply)
        ) { [weak handler] in
            sheet.dismiss(animated: true)
            sheet = nil // To remove strong reference
            handler?.selectedCandidateID = nil
        } rightItemHandler: { [weak handler] in
            defer {
                sheet.dismiss(animated: true)
                sheet = nil
            }
            guard let itemGroup = sheet.itemGroups.first else { return }
            let selectedMails = itemGroup.items.compactMap { item -> String? in
                guard
                    item.markType == .checkMark,
                    let mail = item.userInfo?["mail"] as? String
                else { return nil }
                return mail
            }
            handler?.update(selectedMails: selectedMails, of: group)
        }
        sheet = .init(headerView: header, itemGroups: [itemGroup])
        return sheet
    }
    
    func makeConfigActionSheet(
        for invitee: InviteeInfo,
        inviteeName: String?,
        inviterPermissions: AccessPermission,
        handler: InviteeConfigSheetViewModel
    ) -> PMActionSheet {
        let viewModel = InviteeConfigActionSheetViewModel(
            invitee: invitee,
            inviteeName: inviteeName,
            inviterPermissions: inviterPermissions,
            handler: handler
        )
        let factory = InviteeConfigActionSheetFactory(viewModel: viewModel)
        return factory.makeConfigActionSheet()
    }
    
    func makeMessageSettingSheet(
        isIncludeMessage: Bool,
        handler: InvitationSheetHandler
    ) -> UIHostingController<some View> {
        let host = InvitationMessageSetting(
            isIncludeMessage: isIncludeMessage,
            handler: handler
        ).embeddedInHostingController()
        host.modalPresentationStyle = .overCurrentContext
        host.view.backgroundColor = .clear
        return host
    }
    
    func makeLinkSettingView(
        coordinator: SharingMemberCoordinatorProtocol,
        sharedLink: SharedLink
    ) -> UIHostingController<some View> {
        let viewModel = PublicLinkSettingViewModel(
            dependencies: .init(
                coordinator: coordinator,
                messageHandler: dependencies.messageHandler,
                sharedLinkRepository: makeSharedLinkRepository()
            ),
            sharedLink: sharedLink
        )
        let view = PublicLinkSettingView(viewModel: viewModel)
        let host = view.embeddedInHostingController()
        host.title = Localization.share_action_link_settings
        return host
    }

    func makeMoreActionSheet(
        coordinator: SharingMemberCoordinatorProtocol,
        inviteeViewModel: InviteeViewModel
    ) -> UIHostingController<some View> {
        let viewModel = ShareMoreActionSheetViewModel(
            dependencies: .init(
                coordinator: coordinator,
                messageHandler: dependencies.messageHandler,
                sharedLinkRepository: makeSharedLinkRepository(),
                shareMetadataProvider: dependencies.shareMetaController
            )
        )
        let host = ShareMoreActionSheet(
            viewModel: viewModel,
            inviteeViewModel: inviteeViewModel
        ).embeddedInHostingController()
        host.modalPresentationStyle = .overCurrentContext
        host.view.backgroundColor = .clear
        return host
    }
}

// MARK: - Action sheet
extension SharingConfigViewFactory {
    private func makeGroupActionItems(for group: ContactQueryResult) -> PMActionSheetItemGroup {
        var items: [PMActionSheetItem] = []
        for mail in group.mails.keys.sorted() {
            let isSelected = group.mails[mail] ?? false
            let item = PMActionSheetItem(
                style: .text(mail),
                userInfo: ["mail": mail],
                markType: isSelected ? .checkMark : .none,
                handler: nil
            )
            items.append(item)
        }
        
        return PMActionSheetItemGroup(items: items, style: .multiSelection)
    }
}
