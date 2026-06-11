// Copyright (c) 2025 Proton AG
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

struct StorageDiagnosticsView: View {
    @ObservedObject var viewModel: StorageDiagnosticsViewModel

    init(viewModel: StorageDiagnosticsViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        if viewModel.isAnalyzing {
            spinner
                .onAppear { viewModel.analyze() }
        } else {
            diagnosticsView()
                .padding(.horizontal)
                .navigationTitle("Diagnostics")
        }
    }

    var spinner: some View {
        HStack {
            Text("analyzing")
                .padding(.trailing, 8)
            ProtonSpinner(size: .medium)
        }
    }

    @ViewBuilder
    func diagnosticsView() -> some View {
        VStack {
            ForEach(viewModel.sections) { section in
                diagnosticsCell(for: section)

                if section.clearAction != nil {
                    clearButton(for: section)
                }
            }
            Spacer()
        }
    }

    @ViewBuilder
    func diagnosticsCell(for section: StorageDiagnosticsViewModel.Section) -> some View {
        VStack {
            HStack {
                Text(section.title)
                    .font(.headline)
                Spacer()
                Text(viewModel.formatted(size: section.totalSize))
                    .font(.headline)
            }
            .padding(.top, 12)
            .padding(.horizontal)

            VStack {
                ForEach(section.items) { item in
                    HStack {
                        Text("• \(item.title)")
                        Spacer()
                        Text(viewModel.formatted(size: item.size))
                    }
                }
            }
            .padding(.bottom, 12)
            .padding(.horizontal)
        }
        .background(ColorProvider.InteractionWeakDisabled)
        .cornerRadius(8)
    }

    @ViewBuilder
    func clearButton(for section: StorageDiagnosticsViewModel.Section) -> some View {
        Button {
            section.clearAction?()
        } label: {
            HStack(spacing: 10) {
                IconProvider.eraser
                    .foregroundStyle(ColorProvider.IconNorm)
                    .frame(width: 16, height: 16)
                Text("Clear \(section.title.lowercased())")
                    .foregroundStyle(ColorProvider.TextNorm)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: 32)
            .background(ColorProvider.InteractionWeakDisabled)
            .cornerRadius(8)
        }
    }
}
