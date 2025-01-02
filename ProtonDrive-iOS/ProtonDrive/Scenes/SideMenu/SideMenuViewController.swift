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
import PDUIComponents

class SideMenuViewController: UIViewController {
    private var cancellables = Set<AnyCancellable>()

    let menuViewModel: MenuViewModel
    var onMenuDidSelect: ((MenuViewModel.Destination) -> Void)?

    init(menuViewModel: MenuViewModel) {
        self.menuViewModel = menuViewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.clipsToBounds = true
        
        let menuView = MenuView(vm: menuViewModel).environmentObject(TabBarViewViewModel())
        let menuViewController = UIHostingController(rootView: menuView)
        add(menuViewController)

        menuViewModel.selectedScreenPublisher
            .sink { [unowned self] in self.onMenuDidSelect?($0) }
            .store(in: &cancellables)
    }

}
