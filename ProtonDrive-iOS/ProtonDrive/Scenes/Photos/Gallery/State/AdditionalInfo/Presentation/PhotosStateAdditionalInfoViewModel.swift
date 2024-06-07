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

protocol PhotosStateAdditionalInfoViewModel: ObservableObject {
    var texts: [String]? { get }
}

final class ConcretePhotosStateAdditionalInfoViewModel: PhotosStateAdditionalInfoViewModel {
    private let constraintsController: PhotoBackupConstraintsController
    @Published var texts: [String]?

    init(constraintsController: PhotoBackupConstraintsController) {
        self.constraintsController = constraintsController
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        constraintsController.constraints
            .map { [weak self] constraints in
                let strings = constraints.compactMap { self?.map(constraint: $0) }
                if !strings.isEmpty {
                    return ["Additional QA info:"] + strings
                } else {
                    return nil
                }
            }
            .assign(to: &$texts)
    }

    private func map(constraint: PhotoBackupConstraint) -> String {
        switch constraint {
        case .network:
            return "Network constraint"
        case .storage:
            return "Local storage constraint"
        case .quota:
            return "Cloud storage constraint"
        case .thermalState:
            return "Thermal state constraint"
        case .featureFlag:
            return "Feature flags constraint"
        case .circuitBroken:
            return "The circuit was broken temporarily"
        }
    }
}
