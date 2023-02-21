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

protocol Formatable { }

enum FileFormatter: Formatable { }
enum FolderFormatter: Formatable { }

struct NodeNameFormatter<NodeType: Formatable> {
    private let _name: String
    private let _extension: String?
}

extension NodeNameFormatter where NodeType == FolderFormatter {
    init(fullName: String) {
        self._name = fullName
        _extension = nil
    }

    var name: String {
        _name
    }
}

extension NodeNameFormatter where NodeType == FileFormatter {
    init(fullName: String) {
        (_name, _extension) = fullName.splitIntoNameAndExtension()
    }

    var name: String {
        _name
    }

    var `extension`: String? {
        _extension
    }
}

private extension String {
    func nsRange(of substring: String?) -> NSRange? {
        guard let substring = substring,
            let range = range(of: substring) else { return nil }

        let start = distance(from: startIndex, to: range.lowerBound)
        let end = distance(from: startIndex, to: range.upperBound)

        return NSRange(location: start, length: end - start)
    }

    func splitIntoNameAndExtension() -> (name: String, extension: String?) {
        if count > 2,
           last != ".",
           contains("."),
           let dotIndex = lastIndex(of: "."),
           dotIndex != startIndex {
            let nameRange = startIndex..<dotIndex
            let extensionRange = dotIndex..<endIndex
            return (String(self[nameRange]), String(self[extensionRange]))
        } else {
            return (self, nil)
        }
    }
}
