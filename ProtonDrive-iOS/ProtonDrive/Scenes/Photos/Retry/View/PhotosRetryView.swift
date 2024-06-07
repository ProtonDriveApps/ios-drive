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

import Foundation
import SwiftUI
import PDUIComponents
import ProtonCoreUIFoundations

struct PhotosRetryView: View {
    @ObservedObject var viewModel: PhotosRetryViewModel
    @Environment(\.presentationMode) private var presentationMode
    
    var body: some View {
        VStack {
            List {
                ForEach(viewModel.items) { item in
                    rowFor(item: item)
                    .padding(.vertical, 3)
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            
            bottomButtonsSection
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                leadingButton
            }
            
            ToolbarItem(placement: .principal) {
                topBarTitleSection
            }
        }
        .alert(
            title: { Text($0.title) },
            presenting: $viewModel.presentedAlert,
            actions: { alert in
                ForEach(alert.buttons, id: \.0) { title, action in
                    Button(title, action: { action(viewModel) })
                }
            },
            message: {
                Text($0.message)
            }
        )
        .onChange(of: viewModel.destination) { _ in
            switch viewModel.destination {
            case .unwind: presentationMode.wrappedValue.dismiss()
            case .none: break
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationViewStyle(StackNavigationViewStyle())
        .task {
            await viewModel.task()
        }
    }
    
    private func rowFor(item: PhotosRetryListRowItem) -> some View {
        HStack(alignment: .top) {
            Image(uiImage: UIImage(data: item.image) ?? UIImage(systemName: viewModel.fallbackSystemImage)!)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 32, height: 32)
                .cornerRadius(.small)
            
            Text(item.name)
                .lineLimit(1)
                .foregroundStyle(ColorProvider.TextNorm)
        }
    }
    
    private var bottomButtonsSection: some View {
        VStack(spacing: 12) {
            BlueRectButton(title: viewModel.retryButtonTitle, cornerRadius: .huge) {
                viewModel.pushRetryButton()
            }
            .accessibilityIdentifier("PhotosRetryView.retry.button")
            LightButton(title: viewModel.skipButtonTitle, color: .BrandNorm, font: .body.weight(.light)) {
                viewModel.pushSkipButton()
            }
            .frame(height: 48)
            .accessibilityIdentifier("PhotosRetryView.skip.button")
        }
    }
    
    private var topBarTitleSection: some View {
        VStack {
            Text(viewModel.title)
                .font(.headline)
                .foregroundStyle(ColorProvider.TextNorm)
                .accessibilityIdentifier("PhotosRetryView.title")

            Text(viewModel.subtitle)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(ColorProvider.TextWeak)
                .accessibilityIdentifier("PhotosRetryView.subtitle")
        }
    }
    
    private var leadingButton: some View {
        SimpleCloseButtonView {
            viewModel.destination = .unwind
        }
    }
    
}
