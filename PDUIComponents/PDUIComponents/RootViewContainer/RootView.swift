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
import ProtonCoreUIFoundations

/// Container with Menu underneath and ActionBar switching hierarchies in the main section
public struct RootView<ActiveArea>: View where ActiveArea: View {
    @ObservedObject var vm: RootViewModel
    let activeArea: ActiveArea

    public init(
        vm: RootViewModel,
        @ViewBuilder activeArea: () -> ActiveArea
    ) {
        self.vm = vm
        self.activeArea = activeArea()
    }

    public var body: some View {
        activeArea
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .environmentObject(vm)
    }
}
