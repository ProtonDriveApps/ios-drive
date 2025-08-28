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
import ProtonCoreKeymaker

enum  MainKeyDecryptionError: LocalizedError {
    case encryption(Error)
    case decryption(Error)

    var errorDescription: String? {
        switch self {
        case .decryption(let error):
            return "MainKeyCryptoError.decryption 🗝️: \(error.localizedDescription)"
        case .encryption(let error):
            return "MainKeyCryptoError.encryption 🗝️: \(error.localizedDescription)"
        }
    }
}

/// Class based on the ProtonCoreKeymaker.StringCryptoTransformer, ported here to hav more control over the code and log to sentry when we find errors.
public class DriveStringCryptoTransformer: CryptoTransformer {
    // String -> Data
    override public func transformedValue(_ value: Any?) -> Any? {
        guard let string = value as? NSString else {
            // Should we do something
            return nil
        }

        do {
            let locked = try Locked<String>(clearValue: string as String, with: self.key)
            let result = locked.encryptedValue as NSData
            return result
        } catch {
            Log.error(error: MainKeyDecryptionError.encryption(error), domain: .encryption)
            return nil
        }
    }

    // Data -> NSString
    override public func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? NSData else {
            return nil
        }

        let locked = Locked<String>(encryptedValue: data as Data)
        do {
            let string = try locked.unlock(with: self.key)
            return string as NSString
        } catch {
            Log.error(error: MainKeyDecryptionError.decryption(error), domain: .encryption)
            return nil
        }
    }
}
