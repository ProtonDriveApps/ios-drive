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

public final class SHA1DigestBuilder: DigestBuilder {
    private var sha = Insecure.SHA1()

    public init() {}
    
    public func add(_ data: Data) {
        sha.update(data: data)
    }
    
    public func getResult() -> Data {
        let digest = sha.finalize()
        return Data(digest)
    }
    
    public func hexString() -> String {
        let digest = sha.finalize()
        let bytes = Array(digest.makeIterator())
        return bytes.map { String(format: "%02X", $0) }.joined()
    }
}
