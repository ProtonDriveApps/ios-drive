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
import ProtonCoreUIFoundations

private final class ExampleVM: ObservableObject {
    @Published var selectionNum: Int = 0
}

private struct ExampleView: View {
    let numbers = Array(0...30)
    @ObservedObject var vm = ExampleVM()

    var body: some View {
        List(numbers, id: \.self) { i in
            Button {
                vm.selectionNum = i
            } label: {
                Text("\(i)")
            }
        }
        .overlay(alignment: .bottom) {
            FloatingConfirmSelectionButton(
                selectionNumber: $vm.selectionNum,
                cancelAction: { print("Click cancel") },
                addAction: { print("Click add") }
            )
        }
    }
}

#Preview(body: {
    ExampleView()
})

struct FloatingConfirmSelectionButton: View {
    @Binding private var selectionNumber: Int
    private var cancelAction: () -> Void
    private var addAction: () -> Void

    init(
        selectionNumber: Binding<Int>,
        cancelAction: @escaping () -> Void,
        addAction: @escaping () -> Void
    ) {
        self._selectionNumber = selectionNumber
        self.cancelAction = cancelAction
        self.addAction = addAction
    }

    var body: some View {
        HStack(spacing: 28) {
            cancelButton
            addButton()
        }
        .padding(.horizontal, 34)
    }

    private var cancelButton: some View {
        Button {
            cancelAction()
        } label: {
            IconProvider.cross
                .frame(width: 20, height: 20)
                .foregroundStyle(InternalColor.selectionCrossIconColor)
                .frame(width: 40, height: 40)
                .background(.white)
                .cornerRadius(20)
                .overlay {
                    Circle()
                        .stroke(ColorProvider.SeparatorNorm, lineWidth: 1)
                        .frame(width: 40, height: 40)
                }
        }
    }

    private func addButton() -> some View {
        let text = selectionNumber == 0 ? "Add to album" : "Add \(selectionNumber) to album"
        let background: Color = selectionNumber == 0 ? InternalColor.disabledSelectionBackground : ColorProvider.NotificationSuccess
        return Button {
            addAction()
        } label: {
            // TODO:album localization
            Text(text)
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(height: 54)
                .frame(maxWidth: 600)
                .background(background)
                .cornerRadius(28)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(ColorProvider.BackgroundNorm, lineWidth: 1)
                        .frame(height: 54)
                )
                .accessibilityIdentifier("floating.confirm.check.button")
        }
        .disabled(selectionNumber == 0)
    }
}
