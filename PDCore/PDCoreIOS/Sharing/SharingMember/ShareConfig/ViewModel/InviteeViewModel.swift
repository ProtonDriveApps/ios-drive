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
    @Published private(set) var isFetchingList = true
    @Published private(set) var inviteeList: [InviteeInfo] = []
    /// [Email: Name]
    @Published private var nameDictionary: [String: String] = [:]
    private var onInviteeListIsChanged: (([InvitationInfoWrapper]) -> Void)?
    let inviteButtonTitle = Localization.sharing_member_invite_button
    let sectionHeader = Localization.sharing_member_invitee_section_header
    private var cancellables = Set<AnyCancellable>()
    private let dependencies: Dependencies
    
    init(dependencies: Dependencies) {
        self.dependencies = dependencies
        subscribeForUpdate()
    }

    var hasSharingEditing: Bool {
        dependencies.featureFlagsController.hasSharingEditing
    }

    func name(of email: String) -> String? {
        let name = nameDictionary[email]
        if let name {
            return name.isEmpty ? nil : name
        } else {
            Task { await queryName(of: [email]) }
            return nil
        }
    }
    
    func inviteeRole(invitee: InviteeInfo) -> String {
        let isPending = invitee.externalInvitationState == .pending
        let rowAppending = isPending ? "(\(Localization.sharing_member_invite_send))" : ""
        
        if invitee.permissions.contains([.write, .read]) {
            return "\(Localization.sharing_member_role_editor) \(rowAppending)"
        } else {
            return "\(Localization.sharing_member_role_viewer) \(rowAppending)"
        }
    }
    
    /// - Returns: (Title, Subtitle)
    func info(of invitee: InviteeInfo) -> InviteeCellRenderData {
        if invitee.externalInvitationState == .pending {
            return .init(
                name: nil,
                mail: invitee.inviteeEmail,
                status: Localization.sharing_member_pending,
                statusAccessibilityIdentifier: "Pending"
            )
        }
        
        let canEdit = Localization.sharing_member_permission_can_edit
        let canView = Localization.sharing_member_permission_can_view
        return .init(
            name: name(of: invitee.inviteeEmail),
            mail: invitee.inviteeEmail,
            status: invitee.permissions.isEditor ? canEdit : canView,
            statusAccessibilityIdentifier: invitee.permissions.isEditor ? "editor" : "viewer"
        )
    }
    
    func clickInviteButton() {
        dependencies.coordinator.openInviteView(
            initializedPublisher: dependencies.initializedPublisher, 
            invitationSuccessHandler: self,
            invitedMails: Set(inviteeList.map(\.inviteeEmail))
        )
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
            let name = name(of: invitee.inviteeEmail)
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
            handler: self
        )
    }
    
    func update(permission: AccessPermission, for invitee: InviteeInfo) {
        if permission == invitee.permissions { return }
        guard let shareID = dependencies.shareMetadataController.shareID else { return }
        Task {
            do {
                let newInfo = try await dependencies.inviteeActionHandler.update(
                    permission: permission,
                    for: invitee,
                    shareID: shareID
                )
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
                let share = try await dependencies.shareMetadataController.getDirectShare()
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
            pasteboardWrapper: PasteboardWrapper = .init()
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
        }
    }
    
    struct InviteeCellRenderData {
        let name: String?
        let mail: String
        let status: String
        let statusAccessibilityIdentifier: String
    }
}
