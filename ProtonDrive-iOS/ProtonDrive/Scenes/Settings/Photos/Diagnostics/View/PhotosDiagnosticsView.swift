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

import ProtonCoreUIFoundations
import SwiftUI

struct PhotosDiagnosticsView<ViewModel: PhotosDiagnosticsViewModelProtocol>: View {
    @ObservedObject var viewModel: ViewModel

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigatingView(title: viewModel.data.title, leading: EmptyView(), trailing: EmptyView()) {
            VStack(spacing: 10) {
                if viewModel.data.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: ColorProvider.BrandNorm))
                        .padding(.horizontal)
                }
                HStack {
                    viewModel.data.state.map(makeState)
                    viewModel.data.startButton.map(makeStartButton)
                    viewModel.data.exportButton.map(makeExportButton)
                }
                viewModel.data.sections.map(makeList)
            }
            .padding(.vertical, 16)
        }
        .sheet(
            isPresented: Binding(get: { viewModel.exportedInfosUrls != nil }, set: { _ in viewModel.exportedInfosUrls = nil })
        ) {
            ShareSheet(activityItems: viewModel.exportedInfosUrls ?? [])
        }
    }

    private func makeState(_ title: String) -> some View {
        Text(title)
            .foregroundColor(ColorProvider.TextNorm)
            .font(.system(size: 17))
    }

    private func makeList(from sections: [PhotosDiagnosticsData.Section]) -> some View {
        List {
            ForEach(sections, id: \.self) { section in
                Section(section.title) {
                    ForEach(section.rows) { row in
                        VStack(alignment: .leading) {
                            row.location.map {
                                Text($0)
                                    .font(.system(size: 11))
                                    .fontWeight(.bold)
                            }
                            Text(row.title)
                                .font(.system(size: 15))
                        }
                        .foregroundColor(ColorProvider.TextNorm)
                        .textSelection(.enabled)
                    }
                }
            }
        }
    }

    private func makeStartButton(_ title: String) -> some View {
        Button(action: viewModel.executeDiagnostics) {
            Text(title)
        }
        .foregroundColor(ColorProvider.BrandNorm)
        .padding(12)
        .accessibilityIdentifier("PhotosDiagnostics.StartButton")
    }

    private func makeExportButton(_ title: String) -> some View {
        Button(action: viewModel.exportLogs) {
            Text(title)
        }
        .foregroundColor(ColorProvider.BrandNorm)
        .padding(12)
        .accessibilityIdentifier("PhotosDiagnostics.ExportButton")
    }
}
