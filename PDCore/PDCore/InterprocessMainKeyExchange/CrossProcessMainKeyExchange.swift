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

#if os(iOS)
import Foundation
import FileProvider
import ProtonCoreKeymaker

public enum CrossProcessMainKeyExchange {
    private static var publicLabel = Constants.keychainGroup + ".ephemeral.public"
    private static var privateLabel = Constants.keychainGroup + ".ephemeral.private"

    private static var errorKey = "publicKeyEncoded"
    private static var keychainLabel = "encryptedPin"

    private static var privateEphemeralKey: SecureEnclaveKeyReference?
}

// this happens in FileProvider process
extension CrossProcessMainKeyExchange {
    public static func getMainKeyOrThrowEphemeralKeypair() throws -> MainKey  {
        let keychain = KeychainProvider.shared.keychain
        let secureEnclave = SecureEnclaveHelper(publicLabel: self.publicLabel, privateLabel: self.privateLabel)
        
        guard let pinData = try? keychain.dataOrError(forKey: self.keychainLabel, attributes: nil),
            let privateKey = self.privateEphemeralKey,
            let pinDataDecrypted = try? secureEnclave.decrypt(pinData, privateKey: privateKey) else
        {
            let accessControl = try secureEnclave.accessControl(with: kSecAttrAccessibleWhenUnlockedThisDeviceOnly, flags: .privateKeyUsage)
            
            let keypair = try secureEnclave.generateKeyPair(accessControl: accessControl)
            self.privateEphemeralKey = keypair.private

            let publicKeyData: Data = SecKeyCopyExternalRepresentation(keypair.public.underlying, nil)! as Data
            let userInfo: [String: Any] = [NSUnderlyingErrorKey: CrossProcessErrorExchange.pinExchangeInProgress,
                                           self.errorKey: publicKeyData.base64EncodedString()]

            throw NSError(domain: NSFileProviderError.errorDomain,
                          code: NSFileProviderError.Code.notAuthenticated.rawValue,
                          userInfo: userInfo)
        }

        self.privateEphemeralKey = nil
        return pinDataDecrypted.withUnsafeBytes {
            [UInt8](UnsafeBufferPointer(start: $0, count: pinDataDecrypted.count))
        }
    }
}

// this happens in FileProviderUI process
extension CrossProcessMainKeyExchange {
    public static func sealUserInput(_ mainKey: MainKey, withKeyPlacedInto userInfo: [String: Any]) {
        guard let publicKeyDataRaw = userInfo[self.errorKey] as? String,
            let publicKeyData = Data(base64Encoded: publicKeyDataRaw) else
        {
            return
        }

        let keychain = KeychainProvider.shared.keychain
        let secureEnclave = SecureEnclaveHelper(publicLabel: publicLabel, privateLabel: privateLabel)
        let publicKey = secureEnclave.createKey(ofClass: kSecAttrKeyClassPublic, from: publicKeyData)

        // swiftlint:disable force_try
        let encryptedPin = try! secureEnclave.encrypt(Data(mainKey), publicKey: publicKey)
        // swiftlint:enable force_try
        
        try? keychain.setOrError(encryptedPin, forKey: keychainLabel, attributes: nil)
    }
}
#endif
