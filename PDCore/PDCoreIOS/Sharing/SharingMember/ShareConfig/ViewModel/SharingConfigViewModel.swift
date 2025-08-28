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
import PDCore
import Foundation

protocol SharingConfigUpdater {
    func update(hasInvitee: Bool)
    func update(hasPublicLink: Bool)
}

/// Use to initialize essential information.
final class SharingConfigViewModel: ObservableObject, SharingConfigUpdater {
    private let dependencies: Dependencies
    private let initializedSubject = CurrentValueSubject<Bool, Never>(false)
    var initializedPublisher: AnyPublisher<Bool, Never> {
        initializedSubject.eraseToAnyPublisher()
    }
    @Published private(set) var isShared = false
    private var hasInvitee: Bool = false {
        didSet { isShared = hasInvitee || hasPublicLink }
    }
    private var hasPublicLink: Bool = false {
        didSet { isShared = hasInvitee || hasPublicLink }
    }
    private let sharingType: SharingConfigType

    init(dependencies: Dependencies, sharingType: SharingConfigType) {
        self.dependencies = dependencies
        self.sharingType = sharingType
    }
    
    var hasSharingInvitations: Bool {
        dependencies.featureFlagsController.hasSharingInvitations
    }

    var hasPublicLinkView: Bool {
        switch sharingType {
        case .common:
            return true
        case .album:
            return false
        }
    }

    func viewAppear() {
        if initializedSubject.value { return }
        Task {
            do {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    group.addTask {
                        _ = try await self.dependencies.contactsController.fetchContacts()
                    }
                    group.addTask {
                        _ = try? await self.dependencies.shareMetadataProvider.fetchShareMetaData()
                    }
                    for try await _ in group {}
                }
                initializedSubject.send(true)
            } catch {
                dependencies.messageHandler.handleError(ContactErrors.unableToFetch)
            }
        }
    }
    
    func presentMoreActionSheet() {
        dependencies.coordinator.presentMoreActionSheet()
    }
    
    func update(hasInvitee: Bool) {
        guard self.hasInvitee != hasInvitee else { return }
        self.hasInvitee = hasInvitee
    }
    
    func update(hasPublicLink: Bool) {
        guard self.hasPublicLink != hasPublicLink else { return }
        self.hasPublicLink = hasPublicLink
    }
}

extension SharingConfigViewModel {
    struct Dependencies {
        let coordinator: SharingMemberCoordinatorProtocol
        let contactsController: ContactsControllerProtocol
        let messageHandler: UserMessageHandlerProtocol
        let shareMetadataProvider: ShareMetadataProvider
        let featureFlagsController: FeatureFlagsControllerProtocol
    }
}

public enum SharingConfigType {
    case common
    case album
}
