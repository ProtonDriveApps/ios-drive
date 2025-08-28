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

extension String {
    public var fileName: String {
        return URL(fileURLWithPath: self).deletingPathExtension().lastPathComponent
    }

    public var fileExtension: String {
        return URL(fileURLWithPath: self).pathExtension
    }
}

extension String {
    public func validateNodeName(validator: Validator<String>) throws -> String {
        for error in validator.validate(self) {
            throw error
        }
        return self
    }
}

public extension Array where Element == String {
    func joinedNonEmpty(separator: String) -> String {
        let elements = filter { !$0.isEmpty }
        return elements.joined(separator: separator)
    }
}

extension String {
    var canonicalEmailForm: String {
        replacingOccurrences(of: "[-_.]", with: "", options: [.regularExpression])
            .lowercased()
    }

    var toNilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
