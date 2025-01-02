// Copyright (c) 2024 Proton AG
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

public enum DriveCrypto {
    public static func keyPacketsCount(in armoredMessage: ArmoredMessage) throws -> Int {
        let splitMessage = try unwrap { CryptoGo.CryptoPGPSplitMessage(fromArmored: armoredMessage) }
        var keyPacketsCount: Int = 0
        try execute {
            try splitMessage.getNumberOfKeyPackets(&keyPacketsCount)
        }
        return keyPacketsCount
    }
    
    // For String input
    public static func sign(
        _ input: String,
        context: SignContext,
        privateKey: ArmoredKey,
        passphrase: Passphrase
    ) throws -> Data {
        let message = try unwrap { CryptoGo.CryptoNewPlainMessageFromString(input.trimTrailingSpaces()) }
        let context = CryptoGo.CryptoSigningContext(context.value, isCritical: context.isCritical)
        return try signInternal(
            plainMessage: message,
            context: context,
            privateKey: privateKey,
            passphrase: passphrase
        )
    }
    
    // For Data input
    public static func sign(
        _ input: Data,
        context: String,
        privateKey: ArmoredKey,
        passphrase: Passphrase
    ) throws -> Data {
        let message = try unwrap { CryptoGo.CryptoNewPlainMessage(input) }
        let context = CryptoGo.CryptoSigningContext(context, isCritical: true)
        return try signInternal(
            plainMessage: message,
            context: context,
            privateKey: privateKey,
            passphrase: passphrase
        )
    }
    
    // Shared internal implementation
    private static func signInternal(
        plainMessage: CryptoPlainMessage,
        context: CryptoSigningContext?,
        privateKey: String,
        passphrase: String
    ) throws -> Data {
        let privateKey = try executeAndUnwrap { CryptoGo.CryptoNewKeyFromArmored(privateKey, &$0) }
        let unlockedKey = try privateKey.unlock(passphrase.data(using: .utf8))
        let keyRing = try executeAndUnwrap { CryptoGo.CryptoNewKeyRing(unlockedKey, &$0) }
        defer { keyRing.clearPrivateParams() }
        let pgpSignature = try keyRing.signDetached(withContext: plainMessage, context: context)
        let signature = try executeAndUnwrap { _ in pgpSignature.getBinary() }
        
        return signature
    }
    
    public static func verifyDetached(
        _ signature: Data,
        clearText: String,
        key: ArmoredKey,
        context: VerificationContext,
        verifyTime: Int64? = nil
    ) throws {
        let key = try executeAndUnwrap { CryptoGo.CryptoNewKeyFromArmored(key, &$0) }
        let signature = CryptoGo.CryptoPGPSignature(signature)
        let message = CryptoGo.CryptoNewPlainMessageFromString(clearText.trimTrailingSpaces())
        let keyRing = try executeAndUnwrap { CryptoGo.CryptoNewKeyRing(key, &$0) }
        let context = context.toCryptoVerificationContext()
        try keyRing.verifyDetached(
            withContext: message,
            signature: signature,
            verifyTime: verifyTime ?? Decryptor.cryptoTime,
            verificationContext: context
        )
    }
    
    public struct VerificationContext {
        let value: String
        let required: Required
        
        public enum Required {
            case nonRequired
            case required(since: Date)
            
            var isCritical: Bool {
                switch self {
                case .nonRequired:
                    return false
                case .required:
                    return true
                }
            }
            
            var requirementDetails: (isRequired: Bool, since: Date) {
                switch self {
                case .nonRequired:
                    return (false, Date())
                case .required(let since):
                    return (true, since)
                }
            }
        }
        
        public init(value: String, required: Required) {
            self.value = value
            self.required = required
        }
        
        func toCryptoVerificationContext() -> CryptoVerificationContext? {
            let detail = required.requirementDetails
            return CryptoGo.CryptoVerificationContext(
                value,
                isRequired: detail.isRequired,
                requiredAfter: Int64(detail.since.timeIntervalSince1970)
            )
        }
    }
}

public struct SignContext {
    let value: String
    let isCritical: Bool
    
    public init(value: String, isCritical: Bool) {
        self.value = value
        self.isCritical = isCritical
    }
}
