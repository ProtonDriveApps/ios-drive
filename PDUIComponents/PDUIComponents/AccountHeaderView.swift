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

public struct AccountHeaderView: View {
    let vm: AccountHeaderViewModel
    
    public init(vm: AccountHeaderViewModel) {
        self.vm = vm
    }
    
    public var body: some View {
        VStack(alignment: .leading) {
            HStack {
                HStack(alignment: .center) {
                    Text(vm.abbreviation)
                        .frame(width: 30, height: 30, alignment: .center)
                        .foregroundColor(Color.SidebarTextNorm)
                        .background(Color.BrandNorm)
                        .cornerRadius(.large)

                    VStack(alignment: .leading) {
                        Text(self.vm.name)
                            .foregroundColor(Color.SidebarTextNorm)
                            .font(.body)

                        Text(self.vm.email)
                            .foregroundColor(Color.SidebarTextWeak)
                            .font(.subheadline)
                    }
                }
                
                Spacer()
            }
        }
        .padding(10)
    }
}
