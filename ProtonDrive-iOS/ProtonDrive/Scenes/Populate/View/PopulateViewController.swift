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
import ProtonCoreUIFoundations
import PDUIComponents
import SwiftUI

final class PopulateViewController: UIViewController {
    private lazy var spinner = ViewHosting {
        SpinnerTextView(text: "Getting things ready...")
    }

    var viewModel: PopulateViewModel!

    override public func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ColorProvider.BackgroundNorm
        view.addSubview(spinner)
        spinner.fillSuperview()
        viewModel.viewDidLoad()

        #if DEBUG
        modifyModalFlowsInTests()
        #endif
    }
}

#if DEBUG
extension PopulateViewController {
    
    func modifyModalFlowsInTests() {
        OnboardingFlowTestsManager.defaultOnboardingInTestsIfNeeded()
        OneDollarUpsellFlowTestsManager.defaultUpsellInTestsIfNeeded()
    }

}
#endif
