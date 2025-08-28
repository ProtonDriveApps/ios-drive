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
import PDUIComponents

final class ComputerCellViewModel: ObservableObject {
    private let computerIdentifier: ComputerIdentifier
    private let errorHandler: UserMessageHandlerProtocol
    private let coordinator: ComputersCoordinatorProtocol
    private var cancellables = Set<AnyCancellable>()

    @Published var viewState: ComputerCellViewState = .init(state: .loading)

    init(
        computerIdentifier: ComputerIdentifier,
        repository: DeviceRepository,
        errorHandler: UserMessageHandlerProtocol,
        coordinator: ComputersCoordinatorProtocol
    ) {
        self.computerIdentifier = computerIdentifier
        self.errorHandler = errorHandler
        self.coordinator = coordinator

        repository.observeComputer(with: computerIdentifier)
            .map { computer in
                ComputerCellViewState(state: .loaded(
                    name: computer.decryptedName,
                    iconName: self.getIcon(for: computer.type)
                ))
            }
            .catch { [weak self] error -> Just<ComputerCellViewState> in
                self?.errorHandler.handleError(PlainMessageError(error.localizedDescription))
                return Just(ComputerCellViewState(state: .loading)) // Fallback state
            }
            .receive(on: DispatchQueue.main)
            .assign(to: &$viewState)
    }

    var originalName: String? {
         if case .loaded(let name, _) = viewState.state {
             return name
         }
         return nil
     }

    func cellTapped() {
        coordinator.navigateNext(computer: computerIdentifier)
    }

    private func getIcon(for os: Computer.OS) -> String {
        switch os {
        case .windows: return "ic-brand-windows"
        case .macOS: return "ic-brand-apple"
        case .linux: return "ic-brand-linux"
        case .other: return "ic-tv"
        }
    }

    func getContextMenuItems() -> ContextMenuModel {
        ContextMenuModel(items: [computersRegularSection])
    }

    private var computersRegularSection: ContextMenuItemGroup {
        ContextMenuItemGroup(id: "computersMenuSection", items: [renameMenuItem, detailsMenuItem])
    }

    var renameMenuItem: ContextMenuItem {
        ContextMenuItem(
            sectionItem: ComputersMenu.rename,
            handler: { [weak self] in
                guard let self, let name = self.originalName else { return }
                self.coordinator.rename(computer: self.computerIdentifier, originalName: name)
            }
        )
    }

    var detailsMenuItem: ContextMenuItem {
        ContextMenuItem(
            sectionItem: ComputersMenu.details,
            handler: { [weak self] in
                guard let self else { return }
                self.coordinator.showDetails(for: self.computerIdentifier)
            }
        )
    }
}
