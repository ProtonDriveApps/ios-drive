// Copyright (c) 2023 Proton AG
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

import UIKit
import PDCore
import Combine
import ProtonCore_HumanVerification
import ProtonCore_Keymaker
import ProtonCore_Services
import UserNotifications

final class AuthenticatedDependencyContainer {
    let tower: Tower
    let keymaker: Keymaker
    let networkService: PMAPIService
    let applicationStateController: ApplicationStateOperationsController
    let windowScene: UIWindowScene
    let factory = TabBarViewControllerFactory()
    let childContainers: [Any]
    var humanCheckHelper: HumanCheckHelper?

    init(tower: Tower, keymaker: Keymaker, networkService: PMAPIService, windowScene: UIWindowScene) {
        self.tower = tower
        self.keymaker = keymaker
        self.networkService = networkService
        self.windowScene = windowScene

        let uploadOperationInteractor = UploadOperationInteractor(interactor: tower.fileUploader)
        let applicationRunningResource = ApplicationRunningStateResourceImpl()
        #if SUPPORTS_BACKGROUND_UPLOADS
        let processingController = ProcessingBackgroundOperationController(
            operationInteractor: uploadOperationInteractor,
            taskResource: ProcessingExtensionBackgroundTaskResourceImpl()
        )
        let backgroundOperationController = ExtensionBackgroundOperationController(
            processingController: processingController,
            operationInteractor: uploadOperationInteractor,
            taskResource: ExtensionBackgroundTaskResourceImpl()
        )
        #else
        let backgroundOperationController = ExtensionBackgroundOperationController(
            operationInteractor: uploadOperationInteractor,
            taskResource: ExtensionBackgroundTaskResourceImpl()
        )
        #endif

        applicationStateController = ApplicationStateOperationsController(
            applicationStateResource: applicationRunningResource,
            backgroundOperationController: backgroundOperationController
        )
        
        // Child containers
        childContainers = [
            LocalNotificationsContainer(tower: tower),
            InterruptedUploadsContainer(tower: tower)
        ]
    }

    func makePopulateViewController() -> UIViewController {
        let viewController = PopulateViewController()
        let viewModel = makePopulateViewModel()
        let coordinator = makePopulateCoordinator(viewController)

        viewController.viewModel = viewModel
        viewController.onPopulated = coordinator.showPopulated

        let navigationController = UINavigationController(rootViewController: viewController)
        navigationController.navigationBar.isHidden = true
        navigationController.interactivePopGestureRecognizer?.isEnabled = false

        return navigationController
    }

    private func makePopulateViewModel() -> PopulateViewModel {
        PopulateViewModel(populator: tower, eventsStarter: tower)
    }

    private func makePopulateCoordinator(_ viewController: PopulateViewController) -> PopulateCoordinator {
        PopulateCoordinator(
            viewController: viewController,
            populatedViewControllerFactory: makeHomeViewController
        )
    }
}

protocol DrivePopulator {
    var state: PopulatedState { get }
    func populate(onCompletion: @escaping (Result<Void, Error>) -> Void)
}

extension Tower: DrivePopulator {
    var state: PopulatedState {
        if let root = rootFolder() {
            return .populated(with: root)
        } else {
            return .unpopulated
        }
    }

    func populate(onCompletion: @escaping (Result<Void, Error>) -> Void) {
        self.onFirstBoot(onCompletion)
    }
}

protocol EventsSystemStarter {
    func startEventsSystem()
}

extension Tower: EventsSystemStarter {
    func startEventsSystem() {
        start(runEventsProcessor: true)
    }
}

protocol SignOutManager {
    func signOut()
}

extension Tower: SignOutManager { }

protocol LockManager {
    func onLock()
    func onUnlock()
}

extension Tower: LockManager {
    func onLock() {
        eventProcessor.suspend(true)
    }

    func onUnlock() {
        eventProcessor.suspend(false)
    }
}

extension NotificationCenter {
    func mappedPublisher<T>(for notificationName: Notification.Name, transformer: @escaping (Any?) -> T) -> AnyPublisher<T, Never> {
        self.publisher(for: notificationName).map { transformer($0) }.eraseToAnyPublisher()
    }
}

extension NotificationCenter {
    func mappedPublisher(for notificationName: Notification.Name) -> AnyPublisher<Void, Never> {
        self.publisher(for: notificationName).map { _ in Void() }.eraseToAnyPublisher()
    }
}
