// Copyright (c) 2024 Proton AG
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
import PDUIComponents
import ProtonCoreUIFoundations
import PDLocalization

struct PendingInvitationListScreen<
    ViewModel: PendingInvitationListScreenViewModelProtocol,
    CellView: View
>: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: ViewModel
    let cellViewFactory: (String) -> CellView

    var body: some View {
        VStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    Section(header: header) {
                        ForEach(viewModel.items, id: \.self) { invitationID in
                            cellViewFactory(invitationID)
                        }
                    }
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .onAppear {
                Task {
                    await viewModel.refresh()
                }
            }
            .onDisappear(perform: viewModel.onDisappear)
            .onReceive(viewModel.emptyInvitationPublisher) { _ in
                dismiss()
            }
        }
        .navigationTitle(viewModel.title)
        .background(
            ColorProvider.BackgroundNorm
                .edgesIgnoringSafeArea(.all)
        )
        .overlay {
            viewModel.isFirstLoad ? ProtonSpinner(size: .medium) : nil
        }
    }

    var header: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.4)) { viewModel.toggleSortingOrder() }
        } label: {
            HStack {
                Text(Localization.pending_invitation_screen_sort)
                    .foregroundColor(ColorProvider.TextWeak)
                    .multilineTextAlignment(.leading)

                IconProvider.chevronDown
                    .resizable()
                    .frame(width: 16, height: 16)
                    .foregroundColor(ColorProvider.TextWeak)
                    .rotationEffect(Angle(degrees: viewModel.isAscending ? 0 : 180))
                    .accessibilityLabel(viewModel.isAscending ? "ascending" : "descending")
                Spacer()
            }
            .font(.footnote)
            .accessibilityIdentifier("Menu.SortingSelection")
        }
        .padding()
    }
}
