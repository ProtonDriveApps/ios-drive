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
import CoreData

public typealias CoreDataUploadBlock = UploadBlock

@objc(UploadBlock)
public class UploadBlock: Block {

}

extension UploadBlock {
    // swiftlint:disable:next function_parameter_count
    static func make(volumeID: String, signature: String, signatureEmail: String, index: Int, hash: Data, size: Int, clearSize: Int, moc: NSManagedObjectContext) -> UploadBlock {
        let block = UploadBlock(context: moc)
        block.index = index
        block.sha256 = hash
        block.size = size
        block.clearSize = clearSize
        block.encSignature = signature
        block.signatureEmail = signatureEmail
        block.volumeID = volumeID
        return block
    }
}
