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

import SwiftUI

final class TrashAlertEnvironment {
    let menuItem: Binding<FinderMenu?>
    let presentationMode: Binding<PresentationMode>?
    let cancelSelection: (() -> Void)?
    
    init(menuItem: Binding<FinderMenu?>, presentationMode: Binding<PresentationMode>?, cancelSelection: (() -> Void)?) {
        self.menuItem = menuItem
        self.presentationMode = presentationMode
        self.cancelSelection = cancelSelection
    }

    func onDismiss() {
        menuItem.wrappedValue = nil
    }

    func popScreenIfNeeded() {
        DispatchQueue.main.async {
            self.presentationMode?.wrappedValue.dismiss()
        }
    }
}
