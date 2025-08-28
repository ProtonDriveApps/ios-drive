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

import Foundation

public protocol DebounceResource {
    func debounce(interval: Double, block: @escaping () -> Void)
    func cancel()
}

public final class CommonLoopDebounceResource: DebounceResource {
    private var timer: Timer?
    private var block: (() -> Void)?

    public init() {}

    public func debounce(interval: Double, block: @escaping () -> Void) {
        cancel()
        let timer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            self?.handleUpdate(with: block)
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func handleUpdate(with block: () -> Void) {
        cancel()
        block()
    }

    public func cancel() {
        timer?.invalidate()
        timer = nil
    }
}
