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

@available(*, deprecated, message: "This object will be deprecated soon, please replace it with FileUploaderError")
public enum UploaderErrors: String, Error, LocalizedError {
    private static let uploadFail: NSNotification.Name = .init("ch.protondrive.PDCore.uploadFail")

    case blockLacksMetadata, cleartextLost, retryImpossible, noFileToUpdateRevisionFor, noFileKeyPacket
    case canceled
    case noCredentialInCloudSlot
    case noAddressKeyAvailable
    case noActiveRevision
    case invalidSizeThumbnail
    case noUploadableThumbnail

    public var errorDescription: String? {
        "Could not upload file: \(self.rawValue)"
    }

    public typealias ErrorElements = (domain: String, code: Int)

    public static var noQuotaOnCloudError: ErrorElements { ("ch.protonmail.drive", 200001) } // can not create new volume
    public static var noSpaceOnCloudError: ErrorElements { ("ch.protonmail.drive", 200002) } // no space in volume or account
    public static var lackOfSpaceOnDiskError: ErrorElements { (NSCocoaErrorDomain, NSFileWriteOutOfSpaceError) }
    public static var lackOfSpaceOnDeviceError: ErrorElements { (NSPOSIXErrorDomain, 28) }
}
