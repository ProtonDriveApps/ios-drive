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

import UIKit
import PDCore
import PDUIComponents
import Combine

final class SharedLinkEditorViewController: UIViewController {
    private var closeButton: UIBarButtonItem!
    private var saveButton: UIBarButtonItem!
    private var cancellables = Set<AnyCancellable>()

    private let viewModel: SharedLinkEditorViewModel
    private let viewControllerFactory: () -> UIViewController

    init(
        viewModel: SharedLinkEditorViewModel,
        viewControllerFactory: @escaping () -> UIViewController
    ) {
        self.viewModel = viewModel
        self.viewControllerFactory = viewControllerFactory
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        closeButton = .close(on: self, action: #selector(closeTapped))
        saveButton = .button(on: self, action: #selector(saveTapped), text: viewModel.saveButtonText)

        title = viewModel.title
        navigationItem.setLeftBarButton(closeButton, animated: false)
        navigationItem.setRightBarButton(saveButton, animated: false)

        viewModel.isSaveEnabledPublisher
            .sink { [unowned self] in self.saveButton.isEnabled = $0 }
            .store(in: &cancellables)

        add(viewControllerFactory())
    }

    @objc func saveTapped() {
        viewModel.attempSaving()
    }

    @objc func closeTapped() {
        viewModel.attemptClosing()
    }
}
