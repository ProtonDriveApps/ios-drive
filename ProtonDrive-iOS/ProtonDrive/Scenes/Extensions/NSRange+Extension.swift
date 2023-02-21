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

import UIKit

extension NSRange {
    init?(extensionOf filename: String) {
        let path = URL(fileURLWithPath: filename).pathExtension
        guard !path.isEmpty, let suffixRange = filename.range(of: "." + path) else {
            return nil
        }
        self.init(range: suffixRange, in: filename)
    }

    init?(ofNameWithoutExtension filename: String) {
        let url = URL(fileURLWithPath: filename)
        let pathExtension = url.pathExtension
        let name = url.relativePath.replacingOccurrences(of: "." + pathExtension, with: "")
        guard !name.isEmpty, let nameRange = filename.range(of: name) else {
            return nil
        }
        self.init(range: nameRange, in: filename)
    }

    init?(string: String) {
        guard !string.isEmpty, let nameRange = string.range(of: string) else {
            return nil
        }
        self.init(range: nameRange, in: string)
    }
}

extension NSRange {
    private init(string: String, lowerBound: String.Index, upperBound: String.Index) {
        let utf16 = string.utf16

        let lowerBound = lowerBound.samePosition(in: utf16)!
        let location = utf16.distance(from: utf16.startIndex, to: lowerBound)
        let length = utf16.distance(from: lowerBound, to: upperBound.samePosition(in: utf16)!)

        self.init(location: location, length: length)
    }

    init(range: Range<String.Index>, in string: String) {
        self.init(string: string, lowerBound: range.lowerBound, upperBound: range.upperBound)
    }
    
    init(range: ClosedRange<String.Index>, in string: String) {
        self.init(string: string, lowerBound: range.lowerBound, upperBound: range.upperBound)
    }
}
