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

public final class PhotoTagsMigrationController: WorkingNotifier {
    private let factory: MigrationCommandFactory
    private let constraintController: MigrationConstraintController
    private var command: (Command & WorkingNotifier)?
    private let scheduler: AnySchedulerOf<DispatchQueue>
    private var cancellables = Set<AnyCancellable>()
    private let workSubject = CurrentValueSubject<Bool, Never>(false)
    public var isWorkingPublisher: AnyPublisher<Bool, Never> {
        workSubject.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }

    public init(
        factory: MigrationCommandFactory,
        scheduler: AnySchedulerOf<DispatchQueue> = DispatchQueue.main.eraseToAnyScheduler(),
        constraintController: MigrationConstraintController
    ) {
        self.factory = factory
        self.scheduler = scheduler
        self.constraintController = constraintController

        constraintController.isMigrationAllowedPublisher
            .debounce(for: .seconds(5), scheduler: scheduler)
            .sink { [weak self] (isEnabled, volumeID) in
                guard let self = self else { return }
                if isEnabled {
                    self.setupCommand(volumeID: volumeID)
                } else {
                    self.workSubject.send(false)
                    self.command = nil
                }
            }
            .store(in: &cancellables)
    }

    private func setupCommand(volumeID: String) {
        let command = self.factory.makeMigrationCommand(volumeID: volumeID)
        command.isWorkingPublisher
            .sink { [weak self] isWorking in
                self?.workSubject.send(isWorking)
            }
            .store(in: &cancellables)
        self.command = command
        command.execute()
    }
}
