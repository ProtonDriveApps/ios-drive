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

protocol ComputationalAvailabilityController {
    var availability: AnyPublisher<ComputationalAvailability, Never> { get }
}

final class ConcreteComputationalAvailabilityController: ComputationalAvailabilityController {
    private let subject = CurrentValueSubject<ComputationalAvailability, Never>(.foreground) // Created when app is launched -> starts as foreground
    private let extensionController: BackgroundTaskStateController
    private let processingController: BackgroundTaskStateController
    private let applicationStateController: ApplicationStateController
    private var cancellables = Set<AnyCancellable>()

    var availability: AnyPublisher<ComputationalAvailability, Never> {
        subject
            .eraseToAnyPublisher()
    }

    init(processId: String, extensionController: BackgroundTaskStateController, processingController: BackgroundTaskStateController, applicationStateController: ApplicationStateController) {
        self.extensionController = extensionController
        self.processingController = processingController
        self.applicationStateController = applicationStateController
        subscribeToUpdates(processId: processId)
    }

    /// `processId` is used to differentiate availability per process (logging)
    private func subscribeToUpdates(processId: String) {
        Publishers.CombineLatest3(applicationStateController.state, extensionController.isRunning, processingController.isRunning)
            .map { [weak self] state, isExtensionRunning, isProcessingRunning in
                Log.debug("Computational availability of \(processId). App state: \(state), isExtensionRunning: \(isExtensionRunning), isProcessingRunning: \(isProcessingRunning)", domain: .application)
                return self?.map(state: state, isExtensionRunning: isExtensionRunning, isProcessingRunning: isProcessingRunning) ?? .foreground
            }
            .removeDuplicates()
            .consume {
                Log.info("Changed availability of \(processId) to: \($0)", domain: .application)
            }
            .sink { [weak self] availability in
                self?.subject.send(availability)
            }
            .store(in: &cancellables)
    }

    private func map(state: ApplicationRunningState, isExtensionRunning: Bool, isProcessingRunning: Bool) -> ComputationalAvailability {
        switch state {
        case .foreground:
            return .foreground
        case .background:
            if isExtensionRunning {
                return .extensionTask
            } else if isProcessingRunning {
                return .processingTask
            } else {
                return .suspended
            }
        }
    }
}
