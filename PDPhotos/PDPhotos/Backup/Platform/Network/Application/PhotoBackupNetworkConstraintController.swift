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
import Combine
import PDCore

final class PhotoBackupNetworkConstraintController: PhotoBackupConstraintController {
    private let settingsController: PhotoBackupSettingsController
    private let interactor: ConnectionStateResource
    private let constraintSubject = CurrentValueSubject<Bool, Never>(true)
    private var cancellables = Set<AnyCancellable>()

    var constraint: AnyPublisher<Bool, Never> {
        constraintSubject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    init(settingsController: PhotoBackupSettingsController, interactor: ConnectionStateResource) {
        self.settingsController = settingsController
        self.interactor = interactor

        Publishers.CombineLatest(settingsController.isNetworkConstrained, interactor.state)
            .map { (isConstrainedToWifi, state) -> Bool in
                Log.info("Network state: \(state), isConstrainedToWifi: \(isConstrainedToWifi)", domain: .photosProcessing)
                switch state {
                case .unreachable:
                    return true
                case .reachable(let interface):
                    if interface == .cellular && isConstrainedToWifi {
                        return true
                    } else {
                        return false
                    }
                }
            }
            .sink { [weak self] isBlocked in
                self?.constraintSubject.send(isBlocked)
            }
            .store(in: &cancellables)
    }

}
