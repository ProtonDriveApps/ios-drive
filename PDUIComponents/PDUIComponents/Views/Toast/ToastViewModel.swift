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

import Combine
import Foundation

public class ToastViewModel<T: Hashable>: ObservableObject {
    @Published public var toasts: [T] = []

    private var cancellables = Set<AnyCancellable>()
    private var regulator = PassthroughSubject<T, Never>()

    public init(delay: TimeInterval = 3) {
        regulator
            .delay(for: .seconds(delay), scheduler: DispatchQueue.main)
            .sink { [weak self] toast in
                self?.remove(toast)
            }
            .store(in: &cancellables)
    }

    public func send(_ toast: T) {
        toasts.append(toast)
        regulator.send(toast)
    }

    public func remove(_ toast: T) {
        for i in toasts.indices.reversed() where toasts[i] == toast {
            toasts.remove(at: i)
            return
        }
    }
}
