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

import UIKit
import SwiftUI
import PDCore
import ProtonCoreUIFoundations

protocol CellControllerFactory {
    func makeCellController(id: ComputerIdentifier) -> UIViewController
}

final class ComputersCellControllerFactory: CellControllerFactory {
    private let repository: DeviceRepository
    private let errorHandler: UserMessageHandlerProtocol
    private let coordinator: ComputersCoordinatorProtocol

    init(repository: DeviceRepository, errorHandler: UserMessageHandlerProtocol, coordinator: ComputersCoordinatorProtocol) {
        self.repository = repository
        self.errorHandler = errorHandler
        self.coordinator = coordinator
    }

    func makeCellController(id: ComputerIdentifier) -> UIViewController {
        let viewModel = ComputerCellViewModel(
            computerIdentifier: id,
            repository: repository,
            errorHandler: errorHandler,
            coordinator: coordinator
        )

        let cellView = ComputerCellView(viewModel: viewModel)
        let hostingController = UIHostingController(rootView: cellView)
        return hostingController
    }
}

class ComputersSwiftUICollectionViewCell: UICollectionViewCell {
    static let reuseIdentifier = "ComputersSwiftUICollectionViewCell"

    private var hostingController: UIHostingController<ComputerCellView>?

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Configures the cell using a `ComputerIdentifier`, fetching data from the repository.
    func configure(with identifier: ComputerIdentifier, factory: CellControllerFactory) {
        // Remove old hostingController if it exists
        hostingController?.view.removeFromSuperview()
        hostingController = nil

        // Use the factory to create the view controller
        let cellController = factory.makeCellController(id: identifier)

        // Ensure it's a UIHostingController with ComputerCellView
        guard
            let hostingController = cellController as? UIHostingController<ComputerCellView>,
            let hostingView = hostingController.view else {
            return
        }

        self.hostingController = hostingController
        hostingController.view.backgroundColor = UIColor.clear
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(hostingView)
        hostingView.fillSuperview()
    }
}
