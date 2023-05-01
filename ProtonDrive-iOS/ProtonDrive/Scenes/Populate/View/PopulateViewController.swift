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
import Combine
import PDCore
import ProtonCore_UIFoundations

final class PopulateViewController: UIViewController {
    private var cancellable: Cancellable?

    var viewModel: PopulateViewModel!
    var onPopulated: ((NodeIdentifier) -> Void)?

    override public func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ColorProvider.BackgroundNorm

        cancellable = viewModel.populatedPublisher
            .sink { [weak self] state in
                switch state {
                case let .populated(with: id):
                    self?.onPopulated?(id)
                case .unpopulated:
                    self?.viewModel.populate()
                }
                self?.viewModel.startEventsSystem()
            }
        
        #if DEBUG
        modifyOnboardingFlowInTests()
        #endif
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
}

#if DEBUG
extension PopulateViewController {
    
    func modifyOnboardingFlowInTests() {
        OnboardingFlowTestsManager.defaultOnboardingInTestsIfNeeded()
    }
}
#endif
