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
import ProtonCoreCryptoGoInterface

class FileMobileWriter: NSObject, ProtonCoreCryptoGoInterface.CryptoWriterProtocol {
    var file: FileHandle
    
    init(file: FileHandle) {
        self.file = file
    }
    
    func write(_ b: Data?, n: UnsafeMutablePointer<Int>?) throws {
        if b == nil {
            n?.pointee = 0
            return
        }
        try self.file.write(contentsOf: b!)
        n?.pointee = b!.count
    }
}
