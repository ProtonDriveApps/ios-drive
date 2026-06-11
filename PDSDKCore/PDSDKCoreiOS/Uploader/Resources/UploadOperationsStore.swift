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
import PDCore
import ProtonDriveSDK

actor UploadOperationsStore {
    struct Operation {
        let uploadOperation: ProtonDriveSDK.UploadOperation
        let identifier: AnyVolumeIdentifier
    }

    private var operations: [String: Operation] = [:] // Need to make sure we release!

    func store(id: UUID, operation: Operation) {
        operations[id.uuidString] = operation
    }

    func remove(id: UUID) {
        operations.removeValue(forKey: id.uuidString)
    }

    func get(for id: UUID) -> Operation? {
        operations[id.uuidString]
    }

    func getAll() -> [Operation] {
        Array(operations.values)
    }
}
