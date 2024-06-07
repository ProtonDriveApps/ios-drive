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

/// AsyncButton is a version `Button` with `ProgressView` displayed
/// when performing an `async` `Task`. `Label` gets hidden and progress is shown.
public struct AsyncButton<Label: View>: View {
    var progressViewSize: CGSize
    var action: () async -> Void
    @ViewBuilder var label: () -> Label

    @State private var isPerformingTask = false

    public init(progressViewSize: CGSize, action: @escaping () async -> Void, @ViewBuilder label: @escaping (() -> Label)) {
        self.progressViewSize = progressViewSize
        self.action = action
        self.label = label
    }

    public var body: some View {
        Button(
            action: {
                isPerformingTask = true

                Task {
                    await action()
                    isPerformingTask = false
                }
            },
            label: {
                ZStack {
                    label().opacity(isPerformingTask ? 0 : 1)

                    if isPerformingTask {
                        ProgressView()
                            .frame(width: progressViewSize.width, height: progressViewSize.height)
                            .clipShape(Circle())
                    }
                }
            }
        )
        .disabled(isPerformingTask)
    }
}
