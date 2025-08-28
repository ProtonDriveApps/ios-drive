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
import PDContacts
import PDCore
import PDLocalization
import SwiftUI
import UIKit

protocol SharingMemberCoordinatorProtocol: SharingStartCoordinator {
    func openInviteView(
        initializedPublisher: AnyPublisher<Bool, Never>,
        invitationSuccessHandler: InvitationSuccessHandler,
        invitedMails: Set<String>
    )
    func presentActionSheet(
        for group: ContactQueryResult,
        handler: InvitationSheetHandler
    )
    func presentInviteeConfigSheet(
        for invitee: InviteeInfo,
        inviteeName: String?,
        handler: InviteeConfigSheetViewModel
    )
    func presentMessageSettingSheet(isIncludeMessage: Bool, handler: InvitationSheetHandler)
    func presentMoreActionSheet()
    func openLinkSettingView(sharedLink: SharedLink)
    func popViewController()
    func dismissViewController(completion: (() -> Void)?)
    func didStopSharing()
}

extension SharingMemberCoordinator {
    struct Dependencies {
        let baseHost: String
        let client: Client
        let contactsManager: ContactsManagerProtocol
        let context: NSManagedObjectContext
        let entitlementsManager: EntitlementsManagerProtocol
        let featureFlagsController: FeatureFlagsControllerProtocol
        let node: Node
        let rootViewController: UIViewController?
        let remoteShareMetadataDataSource: RemoteShareMetadataDataSource
        let sessionVault: SessionVault
        let shareCreator: ShareCreatorProtocol
        let storage: StorageManager
        let invitationResultController: InvitationResultControllerProtocol?
    }
}

final class SharingMemberCoordinator: SharingMemberCoordinatorProtocol {
    private weak var rootViewController: UIViewController?
    private weak var configNavigation: UINavigationController?
    private let factory: SharingConfigViewFactory
    private let invitationResultController: InvitationResultControllerProtocol?

    init(dependencies: Dependencies) {
        self.rootViewController = dependencies.rootViewController
        self.invitationResultController = dependencies.invitationResultController
        factory = .init(
            dependencies: .init(
                baseHost: dependencies.baseHost,
                client: dependencies.client,
                contactsController: ContactsController(contactsManager: dependencies.contactsManager),
                contactsManager: dependencies.contactsManager, 
                entitlementsManager: dependencies.entitlementsManager,
                featureFlagsController: dependencies.featureFlagsController,
                messageHandler: UserMessageHandler(),
                sessionVault: dependencies.sessionVault,
                shareMetaController: ShareMetadataController(
                    dependencies: .init(
                        managedObjectContext: dependencies.context,
                        remoteShareDataSource: dependencies.remoteShareMetadataDataSource,
                        shareCreator: dependencies.shareCreator,
                        storage: dependencies.storage
                    ),
                    nodeIdentifier: dependencies.node.identifier
                ),
                storage: dependencies.storage
            )
        )
    }

    func openSharingConfig(sharingType: SharingConfigType) {
        guard let navigationController = rootViewController?.navigationController else {
            Log.error("Navigation controller is nil", error: nil, domain: .application)
            return
        }
        let configView = factory.makeConfigView(
            coordinator: self,
            sharingType: sharingType,
            invitationResultController: invitationResultController
        )
        configNavigation = configView
        navigationController.present(configView, animated: true)
    }
    
    func openInviteView(
        initializedPublisher: AnyPublisher<Bool, Never>,
        invitationSuccessHandler: InvitationSuccessHandler,
        invitedMails: Set<String>
    ) {
        guard let configNavigation else {
            Log.error("ConfigNavigation is nil", error: nil, domain: .sharing)
            return
        }
        let invitationView = factory.makeInvitationView(
            coordinator: self,
            initializedPublisher: initializedPublisher,
            invitationSuccessHandler: invitationSuccessHandler,
            invitedMails: invitedMails
        )
        configNavigation.present(invitationView, animated: true)
    }
    
    func presentActionSheet(
        for group: ContactQueryResult,
        handler: InvitationSheetHandler
    ) {
        guard let root = configNavigation?.presentedViewController else {
            Log.error("ConfigNavigation is nil", error: nil, domain: .sharing)
            return
        }
        let sheet = factory.makeActionSheet(for: group, handler: handler)
        sheet.presentAt(root, hasTopConstant: false, animated: true)
    }
    
    func presentInviteeConfigSheet(
        for invitee: InviteeInfo,
        inviteeName: String?,
        handler: InviteeConfigSheetViewModel
    ) {
        guard let configNavigation else {
            Log.error("ConfigNavigation is nil", error: nil, domain: .sharing)
            return
        }
        let sheet = factory.makeConfigActionSheet(for: invitee, inviteeName: inviteeName, handler: handler)
        sheet.presentAt(configNavigation, hasTopConstant: false, animated: true)
    }
    
    func presentMessageSettingSheet(isIncludeMessage: Bool, handler: InvitationSheetHandler) {
        guard let configNavigation else {
            Log.error("ConfigNavigation is nil", error: nil, domain: .sharing)
            return
        }
        let sheet = factory.makeMessageSettingSheet(isIncludeMessage: isIncludeMessage, handler: handler)
        configNavigation.presentedViewController?.present(sheet, animated: false)
    }
    
    func presentMoreActionSheet() {
        guard let configNavigation else {
            Log.error("ConfigNavigation is nil", error: nil, domain: .sharing)
            return
        }
        let sheet = factory.makeMoreActionSheet(coordinator: self)
        configNavigation.viewControllers.first?.present(sheet, animated: false)
    }
    
    func openLinkSettingView(sharedLink: SharedLink) {
        guard let configNavigation else {
            Log.error("ConfigNavigation is nil", error: nil, domain: .sharing)
            return
        }
        
        let view = factory.makeLinkSettingView(coordinator: self, sharedLink: sharedLink)
        configNavigation.pushViewController(view, animated: true)
    }
    
    func popViewController() {
        guard let configNavigation else {
            Log.error("ConfigNavigation is nil", error: nil, domain: .sharing)
            return
        }
        configNavigation.popViewController(animated: true)
    }
    
    func dismissViewController(completion: (() -> Void)?) {
        guard let configNavigation else {
            Log.error("ConfigNavigation is nil", error: nil, domain: .sharing)
            return
        }
        configNavigation.presentedViewController?.dismiss(animated: true, completion: completion)
    }
    
    func didStopSharing() {
        guard let configNavigation else {
            Log.error("ConfigNavigation is nil", error: nil, domain: .sharing)
            return
        }
        invitationResultController?.inviteeListHasUpdated(to: [])
        // To dismiss share more action sheet
        configNavigation.viewControllers.first?.presentedViewController?.dismiss(animated: false, completion: {
            // To dismiss share config view 
            configNavigation.dismiss(animated: true)
        })
    }
}
