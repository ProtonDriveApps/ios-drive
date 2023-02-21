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
import SwiftUI
import Combine
import ProtonCore_Settings
import ProtonCore_UIFoundations

final class DeleteAccountViewController: UIViewController, PMContainerReloading {
    @ObservedObject var viewModel: DeleteAccountViewModel

    weak var containerReloader: PMContainerReloader?

    private var cancellables: Set<AnyCancellable> = []

    init(viewModel: DeleteAccountViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        let childView = UIHostingController(
            rootView: DeleteAccountView(vm: viewModel) { [unowned self] in
                viewModel.initiateAccountDeletion(over: self)
            })
        add(childView)
        childView.view.backgroundColor = ColorProvider.BackgroundNorm
        childView.view.heightAnchor.constraint(equalToConstant: 48).isActive = true
    }
}
