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
import PDCore
import ProtonCoreUIFoundations
import PDUIComponents

struct NodeDetailsView: View {
    @EnvironmentObject var root: RootViewModel
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var vm: NodeDetailsViewModel
    
    var body: some View {
        VStack {
            SheetHeaderView(title: self.vm.title,
                            dismiss: { self.root.closeCurrentSheet.send() })
                .padding(.top)
            
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(self.vm.details) { detail in
                        HStack(alignment: .firstTextBaseline) {
                            Text(detail.id)
                                .font(.body)
                                .foregroundColor(ColorProvider.TextNorm)
                                .multilineTextAlignment(.leading)
                            
                            Spacer()
                            
                            Text(detail.value)
                                .font(.body)
                                .foregroundColor(ColorProvider.TextWeak)
                                .multilineTextAlignment(.trailing)
                        }
                        .padding()
                        .frame(minHeight: 44)
                    }

                    vm.qaDetails.map { qaDetails in
                        VStack(alignment: .leading) {
                            Spacer()
                            Divider()
                            Text("QA section")
                                .font(.body.bold())
                                .foregroundColor(ColorProvider.TextNorm)
                            Divider()
                            Text("xAttr")
                                .font(.body)
                                .foregroundColor(ColorProvider.TextNorm)
                            Text(qaDetails.extendedAttributes)
                                .font(.body)
                                .foregroundColor(ColorProvider.TextWeak)
                                .multilineTextAlignment(.leading)
                                .padding(.leading, 10)
                        }
                        .padding()
                    }
                }
            }
            .accessibilityIdentifier("NodeDetailsView.\(vm.node.decryptedName)")
            Spacer()
        }
        .background(ColorProvider.BackgroundSecondary)
        .edgesIgnoringSafeArea(.bottom)
    }
}
