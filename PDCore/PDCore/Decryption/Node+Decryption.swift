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

extension Node {
    
    func getDirectParentPack() throws -> (parentPassphrase: String, parentKey: String) {
        guard let parentPassphrase = try (self.parentNode?.decryptPassphrase() ?? getMainDirectSharePassphrase()),
              let parentKey = self.parentNode?.nodeKey ?? self.primaryDirectShare?.key else {
                  throw Decryptor.Errors.noParentPacket
              }
        return (parentPassphrase, parentKey)
    }

    private func getMainDirectSharePassphrase() throws -> String? {
        try self.primaryDirectShare?.decryptPassphrase()
    }

    private func getDirectParentSecret() throws -> DecryptionKey {
        let (parentPassphrase, parentKey) = try getDirectParentPack()
        return DecryptionKey(privateKey: parentKey, passphrase: parentPassphrase)
    }

    /// First time will be calculated and later cached in a transient CoreData property.
    ///
    /// Dispatches between the iterative implementation (default) and the recursive
    /// implementation (kill-switch via `DriveMacDecryptPassphraseIterativeDisabled`).
    /// The iterative path avoids the ~4-frame-per-ancestor stack growth that crashed
    /// FileProvider workers on deeply nested folder trees.
    public func decryptPassphrase() throws -> String {
        #if os(macOS)
        if LocalSettings.shared.driveMacDecryptPassphraseIterativeDisabled {
            return try decryptPassphraseRecursive()
        }
        return try decryptPassphraseIterative()
        #elseif DEBUG
        guard ProcessInfo.processInfo.environment["UNIT_TESTS"] == nil else {
            if LocalSettings.shared.driveMacDecryptPassphraseIterativeDisabled {
                return try decryptPassphraseRecursive()
            }
            return try decryptPassphraseIterative()
        }
        return try decryptPassphraseRecursive()
        #else
        return try decryptPassphraseRecursive()
        #endif
    }

    /// Recursive implementation. Kept as the kill-switch fallback.
    private func decryptPassphraseRecursive() throws -> String {
        if let cached = self.clearPassphrase {
            return cached
        }
        return try performDecryption(telemetryTag: "Node") {
            try decryptNodePassphrase()
        }
    }

    /// Iterative implementation. Walks the parent chain leaf->root in one loop,
    /// then decrypts root->leaf.
    private func decryptPassphraseIterative() throws -> String {
        if let cached = self.clearPassphrase {
            return cached
        }

        // Walk leaf -> root, collecting uncached ancestors. Stops at first cached
        // ancestor or at the root (no parent). Guards for cycles.
        var chain: [Node] = []
        var visited = Set<String>()
        var currentNode: Node = self
        while currentNode.clearPassphrase == nil {
            guard visited.insert(currentNode.id).inserted else {
                throw invalidState("[decryptPassphrase v2] Cycle detected at node \(currentNode.id)")
            }
            chain.append(currentNode)
            guard let parent = currentNode.parentNode else { break }
            currentNode = parent
        }

        // Decrypt root -> leaf
        var capturedParentPassphrase: String?
        var resultPassphrase: String = ""
        for node in chain.reversed() {
            resultPassphrase = try node.performDecryption(telemetryTag: "Node v2") {
                let addressKeys = try node.getAddressPublicKeysOfNodeCreatorWithFallbackToContextShareAddressOrShareCreator()
                let parentNodeKey: DecryptionKey
                if let captured = capturedParentPassphrase, let parent = node.parentNode {
                    parentNodeKey = DecryptionKey(privateKey: parent.nodeKey, passphrase: captured)
                } else {
                    // Top of our chain: parent is either cached (we stopped walking
                    // there) or absent (share root).
                    parentNodeKey = try node.getDirectParentSecret()
                }
                return try node.decryptNodePassphrase(addressKeys: addressKeys, parentNodeKey: parentNodeKey)
            }
            capturedParentPassphrase = resultPassphrase
        }

        // self is the last node processed; fall back to clearPassphrase only if the
        // chain walk broke early (cycle).
        return self.clearPassphrase ?? resultPassphrase
    }

    internal func decryptNodePassphrase() throws -> VerifiedText {
        let addressKeys = try getAddressPublicKeysOfNodeCreatorWithFallbackToContextShareAddressOrShareCreator()
        let parentNodeKey = try getDirectParentSecret()
        return try decryptNodePassphrase(addressKeys: addressKeys, parentNodeKey: parentNodeKey)
    }

    /// Cryptographic core of node-passphrase decryption. Takes both inputs explicitly
    /// so callers can supply them in any order — used both by the zero-arg wrapper
    /// above (recursive parent walk) and by the iterative path (parent walk lifted
    /// into a loop).
    private func decryptNodePassphrase(addressKeys: [PublicKey], parentNodeKey: DecryptionKey) throws -> VerifiedText {
        let signatureEmailIsEmpty = signatureEmail?.isEmpty ?? true
        let verificationKeys = signatureEmailIsEmpty ? [parentNodeKey.privateKey] : addressKeys

        let decrypted: VerifiedText
        do {
            decrypted = try Decryptor.decryptAndVerifyNodePassphrase(
                nodePassphrase,
                armoredSignature: nodePassphraseSignature,
                verificationKeys: verificationKeys,
                decryptionKeys: [parentNodeKey]
            )
        } catch let error where !(error is Decryptor.Errors) {
            DriveIntegrityErrorMonitor.reportMetadataError(for: self)
            throw error
        }

        return decrypted
    }

    /// Applies a `VerifiedText` result, writes the transient cache, and logs
    /// decryption / signature errors with the supplied telemetry tag. Used by both
    /// `decryptPassphraseRecursive` (tag = "Node") and `decryptPassphraseIterative`
    /// (tag = "Node v2") so the only path-specific input is the tag string itself.
    private func performDecryption(
        telemetryTag: String,
        decryptionWork: () throws -> VerifiedText
    ) throws -> String {
        do {
            let decrypted = try decryptionWork()
            let resolved: String
            switch decrypted {
            case .verified(let passphrase):
                resolved = passphrase
            case .unverified(let passphrase, let error):
                Log.error(
                    error: SignatureError(error, telemetryTag, description: "LinkID: \(id) \nShareID: \(shareID) \nVolumeID: \(volumeID)"),
                    domain: .encryption,
                    sendToSentryIfPossible: isSignatureVerifiable()
                )
                resolved = passphrase
            }
            self.clearPassphrase = resolved
            return resolved
        } catch {
            Log.error(
                error: DecryptionError(error, telemetryTag, description: "LinkID: \(id) \nShareID: \(shareID) \nVolumeID: \(volumeID)"),
                domain: .encryption
            )
            throw error
        }
    }

    internal func keyPacket(_ cyphertext: String, newKey: String) throws -> String {
        let (parentPassphrase, parentKey) = try self.getDirectParentPack()
        let sessionKey = try Decryptor.decryptSessionKey(of: cyphertext, privateKey: parentKey, passphrase: parentPassphrase)
        return try Encryptor.encryptSessionKey(sessionKey, withKey: newKey)
    }
}

extension Node {
    
    private func getAddressPublicKeysOfNodeCreatorWithFallbackToContextShareAddressOrShareCreator() throws -> [PublicKey] {
#if os(macOS)
        do {
            return try getAddressPublicKeysOfNodeCreatorWithFallbackToContextShareAddress()
        } catch {
            return try getAddressPublicKeysOfNodeCreatorWithFallbackToShareCreator()
        }
#else
        try getAddressPublicKeysOfNodeCreatorWithFallbackToContextShareAddress()
#endif
    }
    
    private func getAddressPublicKeysOfNodeCreatorWithFallbackToContextShareAddress() throws -> [PublicKey] {
        let addressID = try getContextShareAddressID()

        if let publicKeys = try? getAddressPublicKeys(email: signatureEmail ?? "", addressID: addressID) {
            return publicKeys
        }

        throw SessionVault.Errors.noRequiredAddressKey
    }
    
    private func getAddressPublicKeysOfNodeCreatorWithFallbackToShareCreator() throws -> [PublicKey] {
        if let signatureEmail = signatureEmail, let publicKeys = try? getAddressPublicKeys(email: signatureEmail) {
            return publicKeys
        }

        if let share = self.primaryDirectShare {
            return try share.getAddressPublicKeysOfShareCreator()
        }

        throw SessionVault.Errors.noRequiredAddressKey
    }

    internal func getAddressPublicKeys(email: String, addressID: String) throws -> [PublicKey] {
        SessionVault.current.getPublicKeys(email: email, addressID: addressID)
    }

    internal func getAddressPublicKeys(email: String) throws -> [PublicKey] {
        SessionVault.current.getPublicKeys(for: email)
    }
}
