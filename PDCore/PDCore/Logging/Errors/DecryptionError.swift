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

public struct DecryptionError: LocalizedError {
    let error: Error
    let description: String
    let context: String
    let method: StaticString

    public init(_ error: Error, _ context: String, description: String? = nil, method: StaticString = #function)  {
        self.error = error
        self.context = context
        self.method = method
        self.description = (description == nil) ? "" : "\n\(description!)"
    }

    public var errorDescription: String? {
        "\(context) - \(method) - Decryption Error ❌" + "\n\(error.localizedDescription)" + description
    }
}
