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

import PDClient
import ProtonCoreCryptoGoInterface
import Foundation
import CoreData

struct SharingManager {
    typealias ShareUrlMeta = PDClient.ShareURLMeta
    typealias ShareUrlObj = PDCore.ShareURL

    enum Errors: Error {
        case failedToCreateShareUrlInCoreData
        case failedToGenerateRandomPassword
    }

    private let cloudSlot: CloudSlot
    private let signersKitFactory: SignersKitFactory

    init(cloudSlot: CloudSlot, sessionVault: SessionVault) {
        self.cloudSlot = cloudSlot
        self.signersKitFactory = SignersKitFactory(sessionVault: sessionVault)
    }
}

// MARK: - Create ShareURL
extension SharingManager {
    public func getSecureLink(for node: Node, completion: @escaping (Result<ShareURL, Error>) -> Void) {
        Log.info("SharingManager.getSecureLink, open secure link for \(node.identifier)", domain: .sharing)
        guard node.isShared, let directShare = node.primaryDirectShare else {

            return createSecureLink(node, node.identifier, completion) // The Node is not shared yet => we share it
        }

        // The Node is shared but there is no shareUrl metadata in db
        scanShareURL(directShare, node.identifier, completion)
    }

    private func scanShareURL(_ directShare: Share, _ identifier: NodeIdentifier, _ completion: @escaping (Result<ShareURL, Error>) -> Void) {
        cloudSlot.scanShare(shareID: directShare.id) { scanShareResult in
            switch scanShareResult {
            case let .success(share):
                self.cloudSlot.scanShareURL(shareID: share.id) { resultScanShareURL in
                    switch resultScanShareURL {
                    case let .success(shareUrls):
                        if let link = shareUrls.min(by: { $0.createTime < $1.createTime }) {
                            link.clearPassword = nil
                            completion(.success(link))
                        } else {
                            self.onObtainedShare(share, identifier, completion)
                        }

                    case let .failure(error):
                        Log.info("SharingManager.scanShareURL, link: \(identifier) sharingShare: \(directShare.id), error: \(DriveError(error))", domain: .sharing)
                        completion(.failure(error))
                    }
                }
            case let .failure(error):
                Log.error("SharingManager.scanShareURL, link: \(identifier) sharingShare: \(directShare.id), error: \(DriveError(error))", domain: .sharing)
                completion(.failure(error))
            }
        }
    }

    private func createSecureLink(_ node: Node, _ identifier: NodeIdentifier, _ completion: @escaping (Result<ShareURL, Error>) -> Void) {
        Log.info("SharingManager.createSecureLink, will create a new share and secure link for \(identifier)", domain: .sharing)
        cloudSlot.createShare(node: node) { shareResult in
            switch shareResult {
            case let .success(share):
                self.onObtainedShare(share, identifier, completion)

            case let .failure(error):
                Log.error("SharingManager.createSecureLink, link: \(identifier), error: \(DriveError(error))", domain: .sharing)
                completion(.failure(error))
            }
        }
    }

    private func onObtainedShare(_ share: Share, _ identifier: NodeIdentifier, _ completion: @escaping (Result<ShareURL, Error>) -> Void) {
        Log.info("SharingManager.onObtainedShare, will create a new shareURL for \(identifier)", domain: .sharing)
        createShareURL(share: share) { shareUrlResult in
            switch shareUrlResult {
            case let .success(shareUrlMeta):
                let moc = share.managedObjectContext
                moc?.performAndWait {
                    do {
                        share.root?.isShared = true
                        let shareUrl = try self.shareUrlFromMeta(shareUrlMeta, moc: moc!)
                        try moc?.saveWithParentLinkCheck()
                        Log.info("SharingManager.onObtainedShare, did create a new shareURL for \(identifier), share: \(share.id), shareURL: \(shareUrlMeta.shareURLID)", domain: .sharing)
                        completion(.success(shareUrl))
                    } catch {
                        Log.error("SharingManager.onObtainedShare, link: \(identifier) sharingShare: \(share.id), shareURL: \(shareUrlMeta.shareURLID), error: \(DriveError(error))", domain: .sharing)
                        completion(.failure(error))
                    }
                }

            case let .failure(error):
                Log.error("SharingManager.onObtainedShare, link: \(identifier) sharingShare: \(share.id), error: \(DriveError(error))", domain: .sharing)
                completion(.failure(error))
            }
        }
    }

    func createShareURL(share: Share, handler: @escaping (Result<ShareUrlMeta, Error>) -> Void) {
        cloudSlot.getSRPModulus { result in
            switch result {
            case let .success(modulusResponse):
                share.managedObjectContext?.performAndWait {
                    do {
                        guard let creator = share.creator else {
                            throw share.invalidState("Share should have a creator.")
                        }
                        let createParameters = try self.getNewShareURLParameters(share: share, modulus: modulusResponse.modulus, modulusID: modulusResponse.modulusID, rootCreator: creator)
                        self.cloudSlot.createShareURL(shareID: share.id, parameters: createParameters, completion: handler)

                    } catch let error {
                        handler(.failure(error))
                    }
                }

            case let .failure(error):
                handler(.failure(error))
            }
        }
    }

    private func shareUrlFromMeta(_ meta: ShareUrlMeta, moc: NSManagedObjectContext) throws -> ShareUrlObj {
        self.cloudSlot.update(meta, in: moc)
    }

    private func getNewShareURLParameters(
        share: Share,
        modulus: String,
        modulusID: String,
        rootCreator: String
    ) throws -> NewShareURLParameters  {
        let randomPassword = Decryptor.randomPassword(ofSize: Constants.minSharedLinkRandomPasswordSize)
        let currentAddressKey = try signersKitFactory.make(signatureAddress: rootCreator).addressKey.publicKey
        let encryptedPassword = try Encryptor.encrypt(randomPassword, key: currentAddressKey)

        let srpRandomPassword = try Decryptor.srpForPassword(randomPassword, modulus: modulus)
        let srpPasswordSalt = srpRandomPassword.salt.base64EncodedString()
        let srpPasswordVerifier = srpRandomPassword.verifier.base64EncodedString()

        let shareDecryptionKeys = try share.getShareCreatorDecryptionKeys()
        let shareSessionKey = try Decryptor.decryptSessionKey(share.passphrase.forceUnwrap(), decryptionKeys: shareDecryptionKeys)
        let bcryptedRandomPassword = try Decryptor.bcryptPassword(randomPassword)
        let shareKeyPacket = try Decryptor.encryptSessionKey(shareSessionKey, with: bcryptedRandomPassword.hash).base64EncodedString()
        let sharePasswordSalt = bcryptedRandomPassword.salt.base64EncodedString()

        let parameters = NewShareURLParameters(
            expirationTime: nil,
            expirationDuration: nil,
            maxAccesses: Constants.maxAccesses,
            creatorEmail: share.creator.forceUnwrap(),
            permissions: .read,
            URLPasswordSalt: srpPasswordSalt,
            sharePasswordSalt: sharePasswordSalt,
            SRPVerifier: srpPasswordVerifier,
            SRPModulusID: modulusID,
            flags: .newRandomPassword,
            sharePassphraseKeyPacket: shareKeyPacket,
            password: encryptedPassword,
            name: nil
        )
        return parameters
    }
}

// MARK: - Update ShareURL
extension SharingManager {
    func updateSecureLink(
        shareURL: ShareURL,
        node: NodeIdentifier,
        with details: UpdateShareURLDetails,
        address: AddressManager.Address,
        completion: @escaping (Result<ShareURL, Error>) -> Void
    ) {
        Log.info("SharingManager.updateSecureLink, will update a secure link details \(node)", domain: .sharing)
        updateShareURL(shareURL: shareURL, node: node, details: details) { result in
            switch result {
            case let .success(shareUrlMeta):
                let moc = shareURL.managedObjectContext
                moc?.performAndWait {
                    do {
                        let shareUrl = try self.shareUrlFromMeta(shareUrlMeta, moc: moc!)
                        shareUrl.clearPassword = nil
                        try moc!.saveWithParentLinkCheck()
                        completion(.success(shareUrl))

                    } catch {
                        Log.error("SharingManager.updateShareURL, update locally secure link failed, link: \(node), error: \(DriveError(error))", domain: .sharing)
                        completion(.failure(error))
                    }
                }

            case let .failure(error):
                Log.error("SharingManager.updateShareURL, update secure link failed, link: \(node), error: \(DriveError(error))", domain: .sharing)
                completion(.failure(error))
            }
        }
    }

    /// Internal for unit tests only, returns metadata
    func updateShareURL(
        shareURL: ShareURL,
        node: NodeIdentifier,
        details: UpdateShareURLDetails,
        handler: @escaping (Result<ShareUrlMeta, Error>) -> Void
    ) {
        switch (details.password, details.duration) {
            // Call pure update expiration with value
        case (.unchanged, .expiring(let duration)):
            updatePureDateExpiration(shareURL: shareURL, expirationDuration: Int(duration), handler: handler)

            // Call pure update expiration with nil
        case (.unchanged, .nonExpiring):
            updatePureDateExpiration(shareURL: shareURL, expirationDuration: nil, handler: handler)

            // Call pure update password
        case (.updated(let password), .unchanged):
            updatePurePassword(shareURL: shareURL, newPassword: password, handler: handler)

        case (.updated(let password), .expiring(let duration)):
            // Call mixed update password and expiration
            updateMixedPasswordExpiration(shareURL: shareURL, newPassword: password, expirationDuration: Int(duration), handler: handler)

            // Call mixed update password and expiration
        case (.updated(let password), .nonExpiring):
            updateMixedPasswordExpiration(shareURL: shareURL, newPassword: password, expirationDuration: nil, handler: handler)

            // (.unchanged, .unchanged)
        default:
            fatalError("Should not happen, (.unchanged, .unchanged)")
        }
    }

    private func updatePureDateExpiration(
        shareURL: ShareURL,
        expirationDuration: Int?,
        handler: @escaping (Result<ShareUrlMeta, Error>) -> Void
    ) {
        shareURL.managedObjectContext?.performAndWait {
            let parameters = EditShareURLExpiration(expirationDuration: expirationDuration)
            cloudSlot.updateShareURL(shareURLID: shareURL.id, shareID: shareURL.shareID, parameters: parameters, completion: handler)
        }
    }

    private func updatePurePassword(
        shareURL: ShareURL,
        newPassword: String,
        handler: @escaping (Result<ShareUrlMeta, Error>) -> Void
    ) {
        precondition(newPassword.count >= Constants.minSharedLinkRandomPasswordSize)
        precondition(newPassword.count <= Constants.maxSharedLinkPasswordLength)

        cloudSlot.getSRPModulus { result in
            switch result {
            case let .success(modulusResponse):
                shareURL.managedObjectContext?.performAndWait {
                    do {
                        let parameters = try makeUpdatedPassword(
                            share: shareURL.share,
                            urlPassword: newPassword,
                            modulus: modulusResponse.modulus,
                            modulusID: modulusResponse.modulusID
                        )
                        self.cloudSlot.updateShareURL(shareURLID: shareURL.id, shareID: shareURL.shareID, parameters: parameters, completion: handler)

                    } catch let error {
                        handler(.failure(error))
                    }
                }

            case let .failure(error):
                handler(.failure(error))
            }
        }
    }

    private func updateMixedPasswordExpiration(
        shareURL: ShareURL,
        newPassword: String,
        expirationDuration: Int?,
        handler: @escaping (Result<ShareUrlMeta, Error>) -> Void
    ) {
        precondition(newPassword.count >= Constants.minSharedLinkRandomPasswordSize)
        precondition(newPassword.count <= Constants.maxSharedLinkPasswordLength)

        cloudSlot.getSRPModulus { result in
            switch result {
            case let .success(modulusResponse):
                shareURL.managedObjectContext?.performAndWait {
                    do {
                        let expirationParameters = EditShareURLExpiration(expirationDuration: expirationDuration)
                        let passwordParameters = try makeUpdatedPassword(
                            share: shareURL.share,
                            urlPassword: newPassword,
                            modulus: modulusResponse.modulus,
                            modulusID: modulusResponse.modulusID
                        )

                        let parameters = EditShareURLPasswordAndDuration(expirationParameters, passwordParameters)

                        self.cloudSlot.updateShareURL(shareURLID: shareURL.id, shareID: shareURL.shareID, parameters: parameters, completion: handler)

                    } catch let error {
                        handler(.failure(error))
                    }
                }

            case let .failure(error):
                handler(.failure(error))
            }
        }
    }

    private func makeUpdatedPassword(
        share: Share,
        urlPassword: String,
        modulus: String,
        modulusID: String
    ) throws -> EditShareURLPassword {
        guard let creator = share.creator else {
            throw share.invalidState("Share does not have share creator")
        }
        let currentAddressKey = try signersKitFactory.make(signatureAddress: creator).addressKey.publicKey
        let encryptedPassword = try Encryptor.encrypt(urlPassword, key: currentAddressKey)

        let srpRandomPassword = try Decryptor.srpForPassword(urlPassword, modulus: modulus)
        let srpPasswordSalt = srpRandomPassword.salt.base64EncodedString()
        let srpPasswordVerifier = srpRandomPassword.verifier.base64EncodedString()

        let shareDecryptionKeys = try share.getShareCreatorDecryptionKeys()
        let shareSessionKey = try Decryptor.decryptSessionKey(share.passphrase.forceUnwrap(), decryptionKeys: shareDecryptionKeys)
        let bcryptedRandomPassword = try Decryptor.bcryptPassword(urlPassword)
        let shareKeyPacket = try Decryptor.encryptSessionKey(shareSessionKey, with: bcryptedRandomPassword.hash).base64EncodedString()
        let sharePasswordSalt = bcryptedRandomPassword.salt.base64EncodedString()

        let flag: ShareURLMeta.Flags = urlPassword.count == Constants.minSharedLinkRandomPasswordSize ? .newRandomPassword : .newCustomPassword

        return EditShareURLPassword(
            urlPasswordSalt: srpPasswordSalt,
            sharePasswordSalt: sharePasswordSalt,
            srpVerifier: srpPasswordVerifier,
            srpModulusID: modulusID,
            flags: flag,
            sharePassphraseKeyPacket: shareKeyPacket,
            encryptedUrlPassword: encryptedPassword
        )
    }
}

// MARK: - Delete ShareURL
extension SharingManager {
    func deleteSecureLink(
        _ shareURL: ShareURL,
        shareID: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        cloudSlot.deleteShareURL(shareURL) { result in
            completion(
                result.mapError { error in
                    Log.error(DriveError(error), domain: .networking)
                    return error
                }
            )
        }
    }
}
