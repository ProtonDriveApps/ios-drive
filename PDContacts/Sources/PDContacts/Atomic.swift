// Copyright (c) 2026 Proton AG
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

final class Atomic<A> {

    private let serialAccessQueue = DispatchQueue(label: "ch.proton.atomic_queue")
    private let queueKey = DispatchSpecificKey<Void>()
    private var internalValue: A

    init(_ value: A) {
        self.internalValue = value
        serialAccessQueue.setSpecific(key: queueKey, value: ())
    }

    var value: A {
        sync { internalValue }
    }

    private func sync<T>(_ block: () -> T) -> T {
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            return block() // already on queue, no sync
        }
        return serialAccessQueue.sync { block() }
    }

    func fetch<T>(_ fetchingKeyPath: KeyPath<A, T>) -> T {
        sync { internalValue[keyPath: fetchingKeyPath] }
    }

    func mutate(_ transform: (inout A) -> Void) {
        sync { transform(&self.internalValue) }
    }

    func transform<T>(_ transform: (A) -> T) -> T {
        sync { transform(internalValue) }
    }
}
