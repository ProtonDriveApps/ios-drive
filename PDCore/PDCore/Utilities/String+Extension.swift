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
    func nodeNameIteration() -> (iteration: Int, nameWithoutIteration: String, extension: String) {
        let url = URL(fileURLWithPath: self)
        let pathExtension = url.pathExtension
        let name = url.deletingPathExtension().lastPathComponent
        
        let range = NSRange(location: 0, length: name.utf16.count)
        guard let regex = try? NSRegularExpression(pattern: #" \(\d+\)"#) else {
            assert(false, "Error in regex \(#function)")
            return (0, name, pathExtension)
        }
        guard let match = regex.firstMatch(in: name, options: [], range: range),
            let iterationStringRange = Range(match.range, in: name),
            match.range.upperBound == name.count else
        {
            return (0, name, pathExtension) // no match
        }
        
        let iterationString = String(name[iterationStringRange]).dropFirst(2).dropLast()
        guard let iteration = Int(iterationString) else {
            assert(false, "Regex gave non-number \(#function)")
            return (0, name, pathExtension)
        }
        
        var stringWithoutIteration = name
        stringWithoutIteration.removeSubrange(iterationStringRange)
        return (iteration, stringWithoutIteration, pathExtension)
    }

    public func fileName() -> String {
        return URL(fileURLWithPath: self).deletingPathExtension().lastPathComponent
    }

    public func fileExtension() -> String {
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
