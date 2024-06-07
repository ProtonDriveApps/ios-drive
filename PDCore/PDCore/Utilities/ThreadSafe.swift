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

@propertyWrapper
public class ThreadSafe<Value> {
    private var value: Value
    private let queue: DispatchQueue

    public init(wrappedValue: Value, queue: DispatchQueue) {
        self.value = wrappedValue
        self.queue = queue
    }
    
    public convenience init(wrappedValue: Value) {
        self.init(wrappedValue: wrappedValue, queue: .makeUnique())
    }

    public var wrappedValue: Value {
        get { queue.sync { value } }
        set { queue.async(flags: .barrier) { self.value = newValue } }
    }
}

private extension DispatchQueue {
    static func makeUnique() -> DispatchQueue {
        DispatchQueue(label: "PDCore.ThreadSafe.\(UUID().uuidString)", attributes: .concurrent)
    }
}
