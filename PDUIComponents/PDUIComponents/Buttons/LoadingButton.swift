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
import ProtonCoreUIFoundations

public struct LoadingButton<Label: View>: View {

    private var action: () async -> Void
    @ViewBuilder var label: () -> Label
    @State private var isPerformingTask = false
    private let isLoading: Bool

    public init(isLoading: Bool = false, action: @escaping () async -> Void, @ViewBuilder label: @escaping (() -> Label)) {
        self.isLoading = isLoading
        self.action = action
        self.label = label
    }

    public var body: some View {
        Button(
            action: {
                isPerformingTask = true

                Task {
                    await action()
                    await MainActor.run {
                        isPerformingTask = false
                    }
                }
            },
            label: {
                ZStack(alignment: .center) {
                    label().opacity(isDisabled ? 0.1 : 1)

                    ProtonSpinner(size: .small).opacity(isDisabled ? 1 : 0)
                }
            }
        )
        .disabled(isDisabled)
    }

    private var isDisabled: Bool {
        isPerformingTask || isLoading
    }
}
