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
import PDLocalization
import PDClient
import PDCore
import ProtonCoreHumanVerification // For isValidEmail

protocol InvitationSheetHandler: AnyObject {
    var selectedCandidateID: String? { get set }
    
    func update(selectedMails: [String], of candidate: ContactQueryResult)
    func update(includingMessage: Bool)
}

final class InvitationViewModel: ObservableObject, InvitationSheetHandler {
    @Published private(set) var candidates: [ContactQueryResult] = [] {
        didSet {
            allCandidateValid = candidates.allSatisfy { !$0.isError && !$0.isDuplicated } && !candidates.isEmpty
        }
    }
    @Published private(set) var isInviting = false
    @Published private(set) var isReady = false
    @Published private(set) var queryResult: [ContactQueryResult] = []
    @Published var includingMessage = true
    @Published var inviteMessage = ""
    @Published var permission: AccessPermission = [.read, .write]
    @Published var queryText = ""
    @Published var selectedCandidateID: String?
    let maximumMessageCount = 500
    private var allCandidateValid = false
    private var cancellables = Set<AnyCancellable>()
    private let dependencies: Dependencies
    private var invitedMails: Set<String>
    
    init(dependencies: Dependencies, invitedMails: Set<String>) {
        assert(dependencies.invitationSuccessHandler != nil)
        self.dependencies = dependencies
        self.invitedMails = invitedMails
        
        subscribeForUpdate()
    }
    
    // MARK: - Candidates
    let queryPlaceholder = Localization.sharing_member_placeholder

    func removeCandidate(id: String) {
        candidates.removeAll(where: { $0.id == id })
    }
    
    func add(candidate: ContactQueryResult) {
        if candidate.isGroup {
            appendCandidate(group: candidate)
        } else {
            candidates.append(candidate)
        }
    }
    
    func addCandidate(by keyword: String) {
        if keyword.isEmpty { return }
        if let candidate = queryResult.first(where: { result in
            let keyword = keyword.lowercased()
            if result.name.lowercased() == keyword { return true }
            if String(result.attributedInfo.characters).lowercased() == keyword { return true }
            return false
        }) {
            add(candidate: candidate)
        } else if keyword.isValidEmail() {
            appendCandidate(by: keyword)
        } else {
            appendErrorCandidate(keyword: keyword)
        }
    }
    
    func update(selectedMails: [String], of candidate: ContactQueryResult) {
        candidates.first(where: { $0.id == candidate.id })?.update(selectedMails: selectedMails)
        objectWillChange.send()
    }
    
    // MARK: - Permission
    let permissionRowSectionTitle = Localization.sharing_member_permission_section_title
    var permissionTitle: String {
        if permission.contains([.write, .read]) {
            return Localization.sharing_member_permission_can_edit
        } else {
            return Localization.sharing_member_permission_can_view
        }
    }
    var permissionAccessibilityIdentifier: String {
        return permission.isEditor ? "Editor" : "Viewer"
    }
    
    // MARK: - Invite message
    var inviteMessageTitle: String {
        let title = Localization.sharing_member_include_message_section_title
        if includingMessage {
            return title
        } else {
            let notIncluded = Localization.sharing_member_include_message_not_included
            return "\(title) (\(notIncluded))"
        }
    }
    
    var inviteMessageCount: String {
        "\(inviteMessage.count)/\(maximumMessageCount)"
    }
    
    private var isTooLongInviteMessage: Bool {
        inviteMessage.count > maximumMessageCount
    }
    
    func presentMessageSetting() {
        dependencies.coordinator.presentMessageSettingSheet(isIncludeMessage: includingMessage, handler: self)
    }
    
    func update(includingMessage: Bool) {
        self.includingMessage = includingMessage
    }
    
    // MARK: - Confirm
    var isInviteButtonEnabled: Bool {
        allCandidateValid && !isTooLongInviteMessage
    }
    
    func clickInviteButton() {
        isInviting = true
        let hasSharingExternalInvitations = dependencies.featureFlagsController.hasSharingExternalInvitations
        Task {
            do {
                let share = try await dependencies.shareMetadataProvider.getDirectShare()
                let result = try await dependencies.invitationUserHandler.execute(
                    parameters: .init(
                        candidates: candidates,
                        hasSharingExternalInvitations: hasSharingExternalInvitations,
                        invitationMessage: inviteMessage,
                        isIncludingMessage: includingMessage,
                        itemName: dependencies.shareMetadataProvider.itemName,
                        permission: permission,
                        share: share
                    )
                )
                await MainActor.run {
                    handleInviteSuccess(result: result)
                }
            } catch {
                await MainActor.run {
                    isInviting = false
                }
                Log.error("Invite users failed", error: error, domain: .sharing)
                let displayError = InvitationErrorMappingPolicy().map(error: error)
                dependencies.messageHandler.handleError(displayError)
            }
        }
    }
    
    private func handleInviteSuccess(result: [InviteeInfo]) {
        result
            .map(\.inviteeEmail)
            .forEach { invitedMails.insert($0) }
        dependencies.invitationSuccessHandler?.append(newInvitee: result)
        dependencies.coordinator.dismissViewController { [weak self] in
            guard let self else { return }
            if self.permission.isEditor {
                let text = Localization.sharing_member_editor_added(num: result.count)
                self.dependencies.messageHandler.handleSuccess(text)
            } else {
                let text = Localization.sharing_member_viewer_added(num: result.count)
                self.dependencies.messageHandler.handleSuccess(text)
            }
        }
    }
    
    func presentActionSheet(for group: ContactQueryResult) {
        dependencies.coordinator.presentActionSheet(for: group, handler: self)
    }
    
    func presentDuplicatedInvitationError() {
        let error = PlainMessageError(Localization.sharing_invite_duplicated_member_error)
        dependencies.messageHandler.handleError(error)
    }
}

extension InvitationViewModel {
    private func subscribeForUpdate() {
        dependencies.initializedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isInitialized in
                guard isInitialized else { return }
                self?.isReady = true
            }
            .store(in: &cancellables)
        
        $queryText
            .sink { [weak self] newString in
                self?.handle(newQueryString: newString)
            }
            .store(in: &cancellables)
    }
    
    private func handle(newQueryString: String) {
        var newString = newQueryString
        if !newString.isEmpty {
            let newChar = newString.removeLast()
            if newChar.isWhitespace {
                addCandidate(by: newString)
                DispatchQueue.main.asyncAfter(deadline: .now()) {
                    // Can't update text in $queryText
                    self.queryText = ""
                }
                return
            }
        }
        queryContacts(keyword: newQueryString)
    }
    
    private func queryContacts(keyword: String) {
        Task {
            let candidateIDs = candidates.map(\.id)
            let result = await dependencies.contactsQuerier.execute(
                with: keyword,
                excludedContactIDs: candidateIDs,
                invitedEmails: invitedMails
            )
            await MainActor.run {
                self.queryResult = result
            }
        }
    }
    
    private func appendErrorCandidate(keyword: String) {
        let error = ContactQueryResult(
            id: "error\(Int.random(in: 1...999)) \(Int.random(in: 0...23))",
            attributedName: .init(),
            attributedInfo: .init(),
            name: keyword,
            isError: true,
            mails: []
        )
        candidates.append(error)
    }
    
    private func appendCandidate(by validMail: String) {
        let isDuplicated = invitedMails.contains(validMail)
        let mailCandidate = ContactQueryResult(
            id: validMail,
            attributedName: .init(),
            attributedInfo: .init(),
            name: validMail,
            isError: false,
            isDuplicated: isDuplicated,
            mails: [validMail]
        )
        candidates.append(mailCandidate)
    }
    
    private func appendCandidate(group: ContactQueryResult) {
        let mails = Set(group.mails.keys)
        let invited = Set(invitedMails)
        let areAllMailsInvited = mails.subtracting(invited).isEmpty
        if areAllMailsInvited {
            group.isDuplicated = true
        }
        candidates.append(group)
    }
}

extension InvitationViewModel {
    struct Dependencies {
        let contactsQuerier: ContactsQuerier
        let coordinator: SharingMemberCoordinatorProtocol
        let featureFlagsController: FeatureFlagsControllerProtocol
        let initializedPublisher: AnyPublisher<Bool, Never>
        let invitationUserHandler: InvitationUserHandler
        let invitationSuccessHandler: InvitationSuccessHandler?
        let messageHandler: UserMessageHandlerProtocol
        let shareMetadataProvider: ShareMetadataProvider
    }
}
