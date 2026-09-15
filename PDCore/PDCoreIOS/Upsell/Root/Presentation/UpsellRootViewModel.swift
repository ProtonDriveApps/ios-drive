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

@MainActor
final class UpsellRootViewModel: ObservableObject {
    @Published private(set) var isLoading: Bool = true

    private let controller: UpsellControllerProtocol
    private let coordinator: UpsellCoordinatorProtocol
    private var hasStarted = false

    init(
        controller: UpsellControllerProtocol,
        coordinator: UpsellCoordinatorProtocol
    ) {
        self.controller = controller
        self.coordinator = coordinator
    }

    func onAppear() {
        guard !hasStarted else { return }
        hasStarted = true
        Task { await load() }
    }

    private func load() async {
        switch await controller.loadUpsell() {
        case .showCustomUpsell(let offer):
            coordinator.showCustomUpsell(offer)
        case .fallbackToSubscriptions:
            coordinator.showSubscriptions()
        }
        isLoading = false
    }
}
