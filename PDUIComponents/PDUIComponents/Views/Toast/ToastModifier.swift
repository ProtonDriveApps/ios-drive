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
import Combine
import ProtonCoreUIFoundations

public struct ToastModifier: ViewModifier {
    @ObservedObject var vm: ToastViewModel<Toast>

    public func body(content: Content) -> some View {
        ZStack {
            content

            VStack {
                Spacer()

                ZStack {
                    ForEach(Array(vm.toasts.enumerated()), id: \.element) { index, toast in
                        Banner(
                            message: toast.text,
                            foregroundColor: Color.white,
                            backgroundColor: Color.NotificationSuccess
                        )
                        .frame(minHeight: 48, idealHeight: 48)
                        .padding(.horizontal)
                        .padding(.bottom, 30)
                        .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 4)
                        .stacked(at: index, in: vm.toasts.count)
                        .transition(.move(edge: .bottom))
                        .animation(.linear(duration: 0.2))
                    }
                }
            }
        }
    }
}

extension View {
    public func toasted(vm: ToastViewModel<Toast>) -> some View  {
        self.modifier(ToastModifier(vm: vm))
    }
}

extension View {
    func stacked(at position: Int, in total: Int) -> some View {
        let offset = CGFloat(total - position)
        return self.offset(CGSize(width: 0, height: offset * 3))
    }
}
