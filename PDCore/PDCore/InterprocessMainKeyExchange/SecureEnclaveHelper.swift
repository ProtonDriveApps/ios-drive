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
import Security

private var kKeychainGroupName = Constants.keychainGroup

@objc final class SecureEnclaveKeyReference: NSObject {
    
    @objc let underlying: SecKey
    
    fileprivate init(_ underlying: SecKey) {
        
        self.underlying = underlying
    }
}

@objc final class SecureEnclaveKeyData: NSObject {
    
    let underlying: [String: Any]
    @objc let ref: SecureEnclaveKeyReference
    let data: Data
    
    fileprivate init(_ underlying: CFDictionary) {
        
        let converted = underlying as! [String: Any]
        self.underlying = converted
        self.data = converted[kSecValueData as String] as! Data
        self.ref = SecureEnclaveKeyReference(converted[kSecValueRef as String] as! SecKey)
    }
    
    var hex: String {
        
        return self.data.map { String(format: "%02hhx", $0) }.joined()
    }
}

struct SecureEnclaveHelperError: Error {
    
    let message: String
    let osStatus: OSStatus?
    let link: String
    
    init(message: String, osStatus: OSStatus?) {
        self.message = message
        self.osStatus = osStatus
        
        if let code = osStatus {
            link = "https://www.osstatus.com/search/results?platform=all&framework=Security&search=\(code)"
        } else {
            
            link = ""
        }
    }
}

@objc final class SecureEnclaveHelper: NSObject {
    
    let publicLabel: String
    let privateLabel: String
    let operationPrompt: String
    
    /*!
     *  @param publicLabel  The user visible label in the device's key chain
     *  @param privateLabel The label used to identify the key in the secure enclave
     */
    @objc init(publicLabel: String,
               privateLabel: String,
               operationPrompt: String = "") {
        
        self.publicLabel = publicLabel
        self.privateLabel = privateLabel
        self.operationPrompt = operationPrompt
    }
    
    func sign(_ digest: Data, privateKey: SecureEnclaveKeyReference) throws -> Data {
        
        let blockSize = 256
        let maxChunkSize = blockSize - 11
        
        guard digest.count / MemoryLayout<UInt8>.size <= maxChunkSize else {
            
            throw SecureEnclaveHelperError(message: "data length exceeds \(maxChunkSize)", osStatus: nil)
        }
        
        var digestBytes = [UInt8](repeating: 0, count: digest.count / MemoryLayout<UInt8>.size)
        digest.copyBytes(to: &digestBytes, count: digest.count)
        
        var signatureBytes = [UInt8](repeating: 0, count: blockSize)
        var signatureLength = blockSize
        
        let status = SecKeyRawSign(privateKey.underlying, .PKCS1, digestBytes, digestBytes.count, &signatureBytes, &signatureLength)
        
        guard status == errSecSuccess else {
            
            if status == errSecParam {
                throw SecureEnclaveHelperError(message: "Could not create signature due to bad parameters", osStatus: status)
            } else {
                throw SecureEnclaveHelperError(message: "Could not create signature", osStatus: status)
            }
        }
        
        return Data(bytes: UnsafePointer<UInt8>(signatureBytes), count: signatureLength)
    }
    
    @objc func getPublicKey() -> SecureEnclaveKeyData? {
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: attrKeyTypeEllipticCurve,
            kSecAttrApplicationTag as String: publicLabel,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            kSecReturnData as String: true,
            kSecReturnRef as String: true,
            kSecReturnPersistentRef as String: true,
            kSecAttrAccessGroup as String: kKeychainGroupName
        ]
        
        if let raw = getSecKeyWithQuery(query) {
            return SecureEnclaveKeyData(raw as! CFDictionary)
        } else {
            return nil
        }
    }
    
    @objc func getPrivateKey() -> SecureEnclaveKeyReference? {
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecAttrLabel as String: privateLabel,
            kSecReturnRef as String: true,
            kSecUseOperationPrompt as String: self.operationPrompt,
            kSecAttrAccessGroup as String: kKeychainGroupName
        ]
        
        if let raw = getSecKeyWithQuery(query) {
            return SecureEnclaveKeyReference(raw as! SecKey)
        } else {
            return nil
        }
    }
    
    func generateKeyPair(accessControl: SecAccessControl) throws -> (`public`: SecureEnclaveKeyReference, `private`: SecureEnclaveKeyReference) {
        
        let privateKeyParams: [String: Any] = [
            kSecAttrLabel as String: privateLabel,
            kSecAttrIsPermanent as String: true,
            kSecAttrAccessControl as String: accessControl,
        ]
        let params: [String: Any] = [
            kSecAttrKeyType as String: attrKeyTypeEllipticCurve,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: privateKeyParams
        ]
        var publicKey, privateKey: SecKey?
        
        let status = SecKeyGeneratePair(params as CFDictionary, &publicKey, &privateKey)
        
        guard status == errSecSuccess else {
            
            throw SecureEnclaveHelperError(message: "Could not generate keypair", osStatus: status) // this will also be thrown on Simulator (at least on Xcode 9.2)
        }
        
        return (public: SecureEnclaveKeyReference(publicKey!), private: SecureEnclaveKeyReference(privateKey!))
    }

    @objc func generateKeys(accessControl: SecAccessControl) throws -> [Any] {
        let keys = try generateKeyPair(accessControl: accessControl)
        return [keys.public, keys.private]
    }
    
    func deletePublicKey() throws {
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: attrKeyTypeEllipticCurve,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            kSecAttrApplicationTag as String: publicLabel,
            kSecAttrAccessGroup as String: kKeychainGroupName
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess else {
            
            throw SecureEnclaveHelperError(message: "Could not delete private key", osStatus: status)
        }
    }
    
    func deletePrivateKey() throws {
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecAttrLabel as String: privateLabel,
            kSecReturnRef as String: true,
            kSecAttrAccessGroup as String: kKeychainGroupName
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess else {
            
            throw SecureEnclaveHelperError(message: "Could not delete private key", osStatus: status)
        }
    }
    
    func verify(signature: Data, digest: Data, publicKey: SecureEnclaveKeyReference) throws -> Bool {
        
        var digestBytes = [UInt8](repeating: 0, count: digest.count)
        digest.copyBytes(to: &digestBytes, count: digest.count)
        
        var signatureBytes = [UInt8](repeating: 0, count: signature.count)
        signature.copyBytes(to: &signatureBytes, count: signature.count)
        
        let status = SecKeyRawVerify(publicKey.underlying, .PKCS1, digestBytes, digestBytes.count, signatureBytes, signatureBytes.count)
        
        guard status == errSecSuccess else {
            
            throw SecureEnclaveHelperError(message: "Could not create signature", osStatus: status)
        }
        
        return true
    }

    @objc func encrypt(_ digest: Data, publicKey: SecureEnclaveKeyReference) throws -> Data {
        
        var error: Unmanaged<CFError>?

        let result = SecKeyCreateEncryptedData(publicKey.underlying, SecKeyAlgorithm.eciesEncryptionStandardX963SHA256AESGCM, digest as CFData, &error)
        
        if result == nil {
            
            throw SecureEnclaveHelperError(message: "\(String(error.debugDescription))", osStatus: 0)
        }

        return result! as Data
    }
    
    @objc func decrypt(_ digest: Data, privateKey: SecureEnclaveKeyReference) throws -> Data {
        
        var error: Unmanaged<CFError>?
        
        let result = SecKeyCreateDecryptedData(privateKey.underlying, SecKeyAlgorithm.eciesEncryptionStandardX963SHA256AESGCM, digest as CFData, &error)
        
        if result == nil {

            throw SecureEnclaveHelperError(message: "\(error.debugDescription))", osStatus: 0)
        }
        
        return result! as Data
    }
    
    @objc func forceSavePublicKey(_ publicKey: SecureEnclaveKeyReference) throws {
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: attrKeyTypeEllipticCurve,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            kSecAttrApplicationTag as String: publicLabel,
            kSecValueRef as String: publicKey.underlying,
            kSecAttrIsPermanent as String: true,
            kSecReturnData as String: true,
            kSecAttrAccessGroup as String: kKeychainGroupName
        ]
        
        var raw: CFTypeRef?
        var status = SecItemAdd(query as CFDictionary, &raw)
        
        if status == errSecDuplicateItem {
            
            status = SecItemDelete(query as CFDictionary)
            status = SecItemAdd(query as CFDictionary, &raw)
        }
        
        guard status == errSecSuccess else {
            
            throw SecureEnclaveHelperError(message: "Could not save keypair", osStatus: status)
        }
    }
    
    @objc func accessControl(with protection: CFString = kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, flags: SecAccessControlCreateFlags = [.userPresence, .privateKeyUsage]) throws -> SecAccessControl {
        
        var accessControlError: Unmanaged<CFError>?
        
        let accessControl = SecAccessControlCreateWithFlags(kCFAllocatorDefault, protection, flags, &accessControlError)
        
        guard accessControl != nil else {
            
            throw SecureEnclaveHelperError(message: "Could not generate access control. Error \(String(describing: accessControlError?.takeRetainedValue()))", osStatus: nil)
        }
        
        return accessControl!
    }
    
    private var attrKeyTypeEllipticCurve: String {
        return kSecAttrKeyTypeECSECPrimeRandom as String
    }
    
    private func getSecKeyWithQuery(_ query: [String: Any]) -> CFTypeRef? {
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            return nil
        }
        
        return result!
    }

    func createKey(ofClass keyClass: CFString, from data: Data) -> SecureEnclaveKeyReference {
        let params: [String: Any] = [kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom as String,
                                     kSecAttrKeySizeInBits as String: 256,
                                     kSecAttrKeyClass as String: keyClass]

        var error: Unmanaged<CFError>?
        let publicKey = SecKeyCreateWithData(data as CFData, params as CFDictionary, &error)!
        return SecureEnclaveKeyReference(publicKey)
    }
}
#endif
