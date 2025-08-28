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

import SwiftUI
import Combine
import PDCore
import PDCoreIOS

final class StorageBonusChecklistViewModel: ObservableObject {
    @Published var completedSteps: Set<StorageBonusStep> = []
    @Published var isRefreshing = false

    private var cancellables = Set<AnyCancellable>()
    private let repository: StorageBonusPromoStatusRepositoryProtocol
    private let messageHandler: UserMessageHandlerProtocol

    init(repository: StorageBonusPromoStatusRepositoryProtocol, messageHandler: UserMessageHandlerProtocol = UserMessageHandler()) {
        self.repository = repository
        self.messageHandler = messageHandler
        observeBonusStatus()
    }

    private func observeBonusStatus() {
        repository.publisher
            .map { status in
                Set(StorageBonusStep.allCases.filter { step in
                    status.fulfilledSteps.contains(step.checklistIdentifier)
                })
            }
            .assign(to: &$completedSteps)
    }

    func isStepCompleted(_ step: StorageBonusStep) -> Bool {
        completedSteps.contains(step)
    }

    @MainActor
    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            try await repository.fetchStoragePromoStatus()
        } catch {
            messageHandler.handleError(PlainMessageError(error.localizedDescription))
            Log.error(error: error, domain: .application)
        }
    }
}
