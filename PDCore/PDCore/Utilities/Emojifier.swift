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

import CryptoKit
import Foundation

public enum Emojifier {
    case emoji
    case gothic
    
    static let gothicRanges = [
        0x10330...0x1034F,
        0x1D400...0x1D7FF,
        0x0400...0x04FF,
        0x0000...0x007F,
        0x1F00...0x1FFF,
    ]
    
    static let emojiRanges = [
        0x1F600...0x1F636,
        0x1F645...0x1F64F,
        0x1F910...0x1F91F,
        0x1F300...0x1F321,
        0x1F324...0x1F393,
        0x1f396...0x1f397,
        0x1f399...0x1f39B,
        0x1f39e...0x1f3f0,
        0x1f3f3...0x1f4fd,
        0x1f4ff...0x1F53D,
        0x1f549...0x1f54e,
        0x1f56f...0x1f570,
        0x1f573...0x1f57a,
        0x1f5fa...0x1f5ff,
    ]
    
    private var range: [ClosedRange<Int>] {
        switch self {
        case .gothic: return Self.gothicRanges
        case .emoji: return Self.emojiRanges
        }
    }
    
    private func scalar(_ byte: UInt16) -> UnicodeScalar? {
        var bytesLeft = Int32(byte)
        let suitableRanges = self.range
        .drop {
            let length = Int32($0.upperBound - $0.lowerBound)
            let overlap = bytesLeft - length
            if overlap > 0 {
                bytesLeft -= length
            }
            return overlap > 0
        }
        
        if let range = suitableRanges.first {
            return UnicodeScalar(UInt32(range.lowerBound) + UInt32(bytesLeft))
        } else {
            return nil
        }
    }

    public func symbolicate(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        let hashString = hash
            .compactMap(UInt16.init)
            .chunks(chunkSize: 4)
            .compactMap { $0.reduce(0, +) }
            .compactMap(scalar)
            .compactMap(String.init)
            .joined(separator: " ")
        
        return "[\(hashString)]"
    }
}

fileprivate extension Array {
    func chunks(chunkSize: Int) -> [[Element]] {
        stride(from: 0, to: self.count, by: chunkSize).map {
            Array(self[$0..<Swift.min($0 + chunkSize, self.count)])
        }
    }
}
