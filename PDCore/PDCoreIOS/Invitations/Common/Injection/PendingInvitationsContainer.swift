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
import PDCore
import SwiftUI
import CoreData

public final class PendingInvitationsContainer {
    private let tower: Tower
    private let featureFlagsController: FeatureFlagsControllerProtocol
    private let configuration: PendingInvitationsConfiguration
    private let userMessageHandler: UserMessageHandlerProtocol
    private let pendingInvitationIdsDataSource: PaginatedInvitationsIdentifiersListDataSourceProtocol
    private let invitationsMetadatasDataSource: InvitationsMetadatasDataSourceProtocol
    private let invitationAcceptanceDataSource: InvitationAcceptanceDataSource
    private let invitationRejectionDataSource: InvitationRejectionDataSource
    private let storageManager: StorageManager
    private let localSettings: LocalSettings
    public lazy var changeController = makeChangeController()

    public init(tower: Tower, featureFlagsController: FeatureFlagsControllerProtocol, configuration: PendingInvitationsConfiguration) {
        self.tower = tower
        self.featureFlagsController = featureFlagsController
        self.configuration = configuration
        self.userMessageHandler = UserMessageHandler()
        self.pendingInvitationIdsDataSource = tower.client
        self.invitationsMetadatasDataSource = tower.client
        self.invitationAcceptanceDataSource = tower.client
        self.invitationRejectionDataSource = tower.client
        self.storageManager = tower.storage
        self.localSettings = tower.localSettings
    }

    // MARK: - PendingInvitationsList

    public func makePendingInvitationsListView() -> some View {
        let controller = storageManager.subscriptionToPendingInvitations(linkTypes: configuration.linkTypes)
        let dataSource = FetchedResultsControllerObserver(controller: controller)
        let scanner = PendingInvitationsScanner(
            pendingInvitationIdsDataSource: pendingInvitationIdsDataSource,
            invitationsMetadatasDataSource: invitationsMetadatasDataSource,
            storageManager: storageManager,
            configuration: configuration
        )
        let repository = PendingInvitationRepository(scanner: scanner, observer: dataSource)
        let userPreferencesRepository = PendingInvitationSortPreferenceRepository(localSettings: localSettings)
        let viewModel = PendingInvitationListScreenViewModel(
            repository: repository,
            messageHandler: userMessageHandler,
            userPreferencesRepository: userPreferencesRepository,
            configuration: configuration,
            changeController: changeController
        )
        return PendingInvitationListScreen(
            viewModel: viewModel,
            cellViewFactory: { [unowned self] invitationId in
                self.makePendingInvitationListCellView(invitationID: invitationId)
            }
        )
    }

    public func makePendingInvitationsStatusInteractor() -> some PendingInvitationsStatusMonitorInteractorProtocol {
        let interactor = PendingInvitationsStatusMonitorInteractor(repository: makeInvitationsIdentifiersRepository())
        return FeatureFlagsPendingInvitationsStatusMonitorDecorator(interactor: interactor, controller: featureFlagsController)
    }

    private func makeChangeController() -> PendingInvitationsChangeControllerProtocol {
        PendingInvitationsChangeController()
    }

    private func makePendingInvitationListCellView(invitationID: String) -> some View {
        let viewModel = PendingInvitationListCellViewModel(invitationId: invitationID, repository: PendingInvitationDetailsRepository(storage: storageManager, acceptanceDataSource: invitationAcceptanceDataSource, rejectionDataSource: invitationRejectionDataSource))
        return PendingInvitationListCell(vm: viewModel)
    }

    private func makeInvitationsIdentifiersRepository() -> InvitationsIdentifiersRepositoryProtocol {
        let repository = RemoteInvitationsIdentifiersRepository(remoteDataSource: tower.client, configuration: configuration)
        return repository
    }
}
