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

#if os(iOS)
import Combine
import UIKit

public extension UIViewController {
    func subscribe<ViewModel: ObservableObject>(to viewModel: ViewModel, block: @escaping () -> Void) -> AnyCancellable {
        viewModel
            .objectWillChange
            .makeConnectable()
            .autoconnect()
            // Needs not to be on Runloop.main, since that one is blocked during UI interaction
            .receive(on: DispatchQueue.main)
            .sink { _ in
                block()
            }
    }
}
#endif
