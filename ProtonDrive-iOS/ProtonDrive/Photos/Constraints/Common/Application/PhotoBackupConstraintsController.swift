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

protocol PhotoBackupConstraintsController {
    var constraints: AnyPublisher<PhotoBackupConstraints, Never> { get }
}

final class LocalPhotoBackupConstraintsController: PhotoBackupConstraintsController {
    private let storageController: PhotoBackupConstraintController
    private let networkController: PhotoBackupConstraintController
    private let quotaController: PhotoBackupConstraintController
    private let thermalController: PhotoBackupConstraintController
    private let availableSpaceController: PhotoBackupConstraintController
    private let featureFlagController: PhotoBackupConstraintController
    private let circuitBreakerController: ConstraintController
    private let constraintsSubject: CurrentValueSubject<PhotoBackupConstraints, Never> = .init([])
    private var cancellables = Set<AnyCancellable>()

    var constraints: AnyPublisher<PhotoBackupConstraints, Never> {
        constraintsSubject.eraseToAnyPublisher()
    }

    init(storageController: PhotoBackupConstraintController, networkController: PhotoBackupConstraintController, quotaController: PhotoBackupConstraintController, thermalController: PhotoBackupConstraintController, availableSpaceController: PhotoBackupConstraintController, featureFlagController: PhotoBackupConstraintController, circuitBreakerController: ConstraintController) {
        self.storageController = storageController
        self.networkController = networkController
        self.quotaController = quotaController
        self.thermalController = thermalController
        self.availableSpaceController = availableSpaceController
        self.featureFlagController = featureFlagController
        self.circuitBreakerController = circuitBreakerController
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        let cloudPublisher = Publishers.CombineLatest3(quotaController.constraint, featureFlagController.constraint, circuitBreakerController.constraint)
        let storagePublisher = Publishers.CombineLatest(storageController.constraint, availableSpaceController.constraint)
            .map { $0.0 || $0.1 }
        
        Publishers.CombineLatest4(storagePublisher, networkController.constraint, cloudPublisher, thermalController.constraint)
            .sink { [weak self] isStorageConstrained, isNetworkConstrained, isBackendConstrained, isThermalStateConstranined in
                let isQuotaExceeded = isBackendConstrained.0
                let isFeatureFlagDisabled = isBackendConstrained.1
                let isCircuitBroken = isBackendConstrained.2
                self?.handleUpdate(isStorageConstrained: isStorageConstrained, isNetworkConstrained: isNetworkConstrained, isQuotaExceeded: isQuotaExceeded, isThermalStateConstranined: isThermalStateConstranined, isFeatureFlagDisabled: isFeatureFlagDisabled, isCircuitBroken: isCircuitBroken)
            }
            .store(in: &cancellables)
    }

    private func handleUpdate(isStorageConstrained: Bool, isNetworkConstrained: Bool, isQuotaExceeded: Bool, isThermalStateConstranined: Bool, isFeatureFlagDisabled: Bool, isCircuitBroken: Bool) {
        let constraints = [
            isStorageConstrained ? PhotoBackupConstraint.storage : nil,
            isNetworkConstrained ? .network : nil,
            isQuotaExceeded ? .quota : nil,
            isThermalStateConstranined ? .thermalState : nil,
            isFeatureFlagDisabled ? .featureFlag : nil,
            isCircuitBroken ? .circuitBroken : nil
        ].compactMap { $0 }
        let constraintsSet = Set(constraints)
        Log.info("Photos backup constraints: \(constraintsSet)", domain: .photosProcessing)
        constraintsSubject.send(constraintsSet)
    }
}
