// Copyright (c) 2025 Proton AG
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
import Combine
import PDCoreIOS

@MainActor
class ComputersViewModel: ObservableObject {
    @Published var computers: [ComputerIdentifier] = []
    @Published var upgradeRequirementLevel: UpgradeRequirementLevel = .none

    var subscriptions = Set<AnyCancellable>()
    let upgradeRequirementBannerController: UpgradeRequirementBannerControllerProtocol

    private let observer: ComputersObserverInteractorProtocol
    private let scanner: ComputersScannerInteractorProtocol
    private let loadStateRepository: ComputersLoadStateRepositoryProtocol
    private let coordinator: ComputersCoordinatorProtocol
    private let messageHandler: UserMessageHandlerProtocol
    private let performanceMetricsController: PerformanceMetricsControllerProtocol?
    private let updateTrigger = PassthroughSubject<Void, Never>()
    private let goBackPublisher: AnyPublisher<Void, Never>

    init(
        scanner: ComputersScannerInteractorProtocol,
        observer: ComputersObserverInteractorProtocol,
        loadStateRepository: ComputersLoadStateRepositoryProtocol,
        goBackPublisher: AnyPublisher<Void, Never> = DriveNotification.virtualBack.publisher.map { _ in Void() }.eraseToAnyPublisher(),
        messageHandler: UserMessageHandlerProtocol,
        coordinator: ComputersCoordinatorProtocol,
        performanceMetricsController: PerformanceMetricsControllerProtocol?,
        upgradeRequirementBannerController: UpgradeRequirementBannerControllerProtocol
    ) {
        self.scanner = scanner
        self.observer = observer
        self.loadStateRepository = loadStateRepository
        self.coordinator = coordinator
        self.messageHandler = messageHandler
        self.goBackPublisher = goBackPublisher
        self.performanceMetricsController = performanceMetricsController
        self.upgradeRequirementBannerController = upgradeRequirementBannerController
    }

    var isInitialLoad: Bool {
        loadStateRepository.isInitialLoad
    }

    func fetchComputers() async {
        do {
            try await scanner.scanComputers()
            guard loadStateRepository.isInitialLoad else {
                return
            }
            loadStateRepository.isInitialLoad = false
            updateTrigger.send(())
        } catch {
            let plainError = PlainMessageError(error.localizedDescription)
            messageHandler.handleError(plainError)
        }
    }

    func onViewDidLoad() {
        observer
            .computers
            .removeDuplicates()
            .merge(with: updateTrigger.map { _ in self.computers })
            .sink { [weak self] in
                self?.performanceMetricsController?.updateTab(cacheCount: $0.count, in: .computers)
                self?.computers = $0
            }
            .store(in: &subscriptions)

        goBackPublisher.sink { [weak self] in
            self?.coordinator.goBack()
        }
        .store(in: &subscriptions)

        upgradeRequirementBannerController
            .subscribeToUpgradeRequirement(currentTab: .computers)
            .sink { [weak self] level in
                self?.upgradeRequirementLevel = level
            }
            .store(in: &subscriptions)

    }

    func openSideMenu() {
        coordinator.notifySideMenuToggle()
    }

    func reportListIsShown() {
        performanceMetricsController?.reportTabToFirstItem(pageType: .computers)
    }
}
