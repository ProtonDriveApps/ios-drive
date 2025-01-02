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

import Combine
import PDCore

enum NetworkConstraint: Equatable {
    case noWifi
    case noConnection
}

protocol PhotoBackupNetworkControllerProtocol: PhotoBackupConstraintController {
    var specificConstraint: AnyPublisher<NetworkConstraint?, Never> { get }
    func getInterface() -> NetworkState.Interface?
}

final class PhotoBackupNetworkController: PhotoBackupNetworkControllerProtocol {
    private let backupController: PhotosBackupController
    private let settingsController: PhotoBackupSettingsController
    private let interactor: NetworkStateInteractor
    private var constraintSubject = CurrentValueSubject<NetworkConstraint?, Never>(nil)
    private var cancellables = Set<AnyCancellable>()
    private var lastInterface: NetworkState.Interface?

    var specificConstraint: AnyPublisher<NetworkConstraint?, Never> {
        constraintSubject.eraseToAnyPublisher()
    }

    var constraint: AnyPublisher<Bool, Never> {
        specificConstraint
            .map { $0 != nil }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    init(backupController: PhotosBackupController, settingsController: PhotoBackupSettingsController, interactor: NetworkStateInteractor) {
        self.backupController = backupController
        self.settingsController = settingsController
        self.interactor = interactor
        subscribeToUpdates()
    }

    func getInterface() -> NetworkState.Interface? {
        lastInterface
    }

    private func subscribeToUpdates() {
        backupController.isAvailable
            .map { $0 == .available }
            .sink { [weak self] isAvailable in
                self?.handleBackup(isAvailable)
            }
            .store(in: &cancellables)
        
        Publishers.CombineLatest(settingsController.isNetworkConstrained, interactor.state)
            .map { isConstrainedToWifi, state -> NetworkConstraint? in
                Log.info("PhotoBackupNetworkController network state: \(state), isConstrainedToWifi: \(isConstrainedToWifi)", domain: .photosProcessing)
                switch state {
                case .unreachable:
                    return .noConnection
                case let .reachable(interface):
                    if isConstrainedToWifi && interface == .cellular {
                        return .noWifi
                    } else {
                        return nil
                    }
                }
            }
            .removeDuplicates()
            .sink { [weak self] constraint in
                Log.info("PhotoBackupNetworkController constraint: \(String(describing: constraint))", domain: .photosProcessing)
                self?.constraintSubject.send(constraint)
            }
            .store(in: &cancellables)

        interactor.state
            .map { state -> NetworkState.Interface? in
                switch state {
                case let .reachable(interface):
                    return interface
                case .unreachable:
                    return nil
                }
            }
            .sink { [weak self] interface in
                self?.lastInterface = interface
            }
            .store(in: &cancellables)
    }

    private func handleBackup(_ isAvailable: Bool) {
        if isAvailable {
            interactor.execute()
        } else {
            interactor.cancel()
        }
    }
}
