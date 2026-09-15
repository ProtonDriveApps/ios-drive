// Copyright (c) 2026 Proton AG
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
import SwiftUI
import ProtonCoreUIFoundations

public struct NNodeDetailsView: View {
    @Environment(\.dismiss) var dismiss
    let vm: NNodeDetailsViewModel

    public init(vm: NNodeDetailsViewModel) {
        self.vm = vm
    }

    public var body: some View {
        VStack {
            SheetHeaderView(title: self.vm.title, dismiss: { dismiss() })
                .padding(.top)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(self.vm.details, id: \.key) { detail in
                        makeRow(from: detail)
                    }

                    vm.qaDetails.map { qaDetails in
                        VStack(spacing: 0) {
                            Spacer()
                            Divider()
                            Text("QA section")
                                .font(.body.bold())
                                .foregroundColor(ColorProvider.TextNorm)
                                .padding(10)
                            Divider()
                            ForEach(qaDetails, id: \.key) { detail in
                                makeRow(from: detail)
                            }
                        }
                    }
                }
            }
            .accessibilityIdentifier("NodeDetailsView.\(vm.nodeName)")
            Spacer()
        }
        .background(ColorProvider.BackgroundSecondary)
        .edgesIgnoringSafeArea(.bottom)
    }

    private func makeRow(from detail: (key: String, value: String)) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(detail.key)
                .font(.body)
                .foregroundColor(ColorProvider.TextNorm)
                .multilineTextAlignment(.leading)

            Spacer()

            Text(detail.value)
                .font(.body)
                .foregroundColor(ColorProvider.TextWeak)
                .multilineTextAlignment(.trailing)
                .accessibilityIdentifier(detail.key + "_value")
        }
        .padding()
        .frame(minHeight: 44)
    }
}
#endif
