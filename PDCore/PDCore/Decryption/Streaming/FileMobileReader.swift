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

class FileMobileReader: NSObject, ProtonCoreCryptoGoInterface.HelperMobileReaderProtocol {
    enum Errors: Error {
        case failedToCreateCryptoHelper
    }
    let file: FileHandle
    
    init(file: FileHandle) {
        self.file = file
    }
    
    func read(_ max: Int) throws -> ProtonCoreCryptoGoInterface.HelperMobileReadResult {
        let data = try self.file.read(upToCount: max) ?? Data()
        guard let helper = CryptoGo.HelperMobileReadResult(data.count, eof: data.isEmpty, data: data) else {
            assertionFailure("Failed to create Helper of Crypto - should not happen")
            throw Errors.failedToCreateCryptoHelper
        }
        return helper
    }
}
