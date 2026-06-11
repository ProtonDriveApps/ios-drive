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

import Combine
import PDCore
import PDCoreIOS

enum PhotoVolumeBootstrapState: Equatable {
    case uninitialized
    case inProgress
    case failed(String)
    case finished(PhotoStreamConfiguration)
}

protocol PhotoVolumeBootstrapControllerProtocol {
    var state: AnyPublisher<PhotoVolumeBootstrapState, Never> { get }
    func bootstrap()
}

final class PhotoVolumeBootstrapController: PhotoVolumeBootstrapControllerProtocol {
    private let featureFlagsController: FeatureFlagsControllerProtocol
    private let errorController: ErrorSetControllerProtocol
    private let facade: PhotoVolumeBootstrapFacade
    private let stateSubject = CurrentValueSubject<PhotoVolumeBootstrapState, Never>(.uninitialized)
    private var cancellables = Set<AnyCancellable>()

    var state: AnyPublisher<PhotoVolumeBootstrapState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    init(facade: PhotoVolumeBootstrapFacade, featureFlagsController: FeatureFlagsControllerProtocol, errorController: ErrorSetControllerProtocol) {
        self.facade = facade
        self.featureFlagsController = featureFlagsController
        self.errorController = errorController
        subscribeToUpdates()
    }

    func bootstrap() {
        switch stateSubject.value {
        case .uninitialized, .failed:
            stateSubject.send(.inProgress)
            let input = PhotoVolumeBootstrapInput(canCreatePhotoVolume: true)
            facade.execute(with: input)
        case .inProgress, .finished:
            break
        }
    }

    private func subscribeToUpdates() {
        facade.result
            .sink { [weak self] result in
                self?.handle(result)
            }
            .store(in: &cancellables)
    }

    private func handle(_ result: PhotoVolumeBootstrapResult) {
        switch result {
        case let .success(result):
            handleOutput(result)
        case let .failure(error):
            errorController.setError(error)
            stateSubject.send(.failed(error.localizedDescription))
        }
    }

    private func handleOutput(_ result: PhotoVolumeBootstrapOutput) {
        switch result {
        case let .photoVolume(volumeId):
            let configuration = PhotoStreamConfiguration(volumeId: volumeId)
            stateSubject.send(.finished(configuration))
        }
    }
}
