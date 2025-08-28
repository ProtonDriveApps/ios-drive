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

extension PhotoRevision {
    public func decryptExif() -> Data {
        do {
            if let transientClearExif {
                return transientClearExif
            }

            let addressKeys = try getAddressPublicKeysOfRevision()
            let signatureAddressIsEmpty = signatureAddress?.isEmpty ?? true
            let verificationKeys = signatureAddressIsEmpty ? [file.nodeKey] : addressKeys

            guard let dataPacket = Data(base64Encoded: exif) else {
                throw invalidState("Could not decode exif data packet.")
            }

            let sessionKey = try decryptContentSessionKey()
            let decrypted: VerifiedBinary
            do {
                decrypted = try Decryptor.decryptAndVerifyExif(
                    dataPacket,
                    contentSessionKey: sessionKey,
                    verificationKeys: verificationKeys
                )
            } catch let error where !(error is Decryptor.Errors) {
                DriveIntegrityErrorMonitor.reportMetadataError(for: file)
                throw error
            }

            switch decrypted {
            case .verified(let exif):
                self.transientClearExif = exif
                return  exif

            case .unverified(let exif, let error):
                Log.error(error: SignatureError(error, "EXIF", description: "RevisionID: \(id) \nLinkID: \(file.id) \nVolumeID: \(file.volumeID)"), domain: .encryption, sendToSentryIfPossible: photo.isSignatureVerifiable())
                self.transientClearExif = exif
                return exif
            }
        } catch {
            Log.error(error: DecryptionError(error, "EXIF", description: "RevisionID: \(id) \nLinkID: \(file.id) \nVolumeID: \(file.volumeID)"), domain: .encryption)
            return Data()
        }
    }
}
