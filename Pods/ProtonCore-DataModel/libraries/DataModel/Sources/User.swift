//
//  User.swift
//  ProtonCore-DataModel - Created on 17/03/2020.
//
//  Copyright (c) 2022 Proton Technologies AG
//
//  This file is part of Proton Technologies AG and ProtonCore.
//
//  ProtonCore is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonCore is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonCore.  If not, see <https://www.gnu.org/licenses/>.

import Foundation

public struct User: Codable, Equatable {

    public let ID: String
    public let name: String?
    public let usedSpace: Double
    public let currency: String
    public let credit: Int
    public let maxSpace: Double
    public let maxUpload: Double
    public let role: Int
    public let `private`: Int
    public let subscribed: Subscribed
    public let services: Int
    public let delinquent: Int
    public let orgPrivateKey: String?
    public let email: String?
    public let displayName: String?
    public let keys: [Key]
    // public let driveEarlyAccess: Int
    // public let mailSettings: MailSetting
    // public let addresses: [Address]

    public var hasAnySubscription: Bool {
        !subscribed.isEmpty
    }

    public struct Subscribed: OptionSet, Codable, Equatable {
        public let rawValue: UInt8

        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }

        /// 1: has `Mail` subscription.
        public static let mail     = Subscribed(rawValue: 1 << 0)
        /// 2: has `Drive` subscription.
        public static let drive    = Subscribed(rawValue: 1 << 1)
        /// 4: has `VPN` subscription.
        public static let vpn      = Subscribed(rawValue: 1 << 2)
    }

    public init(ID: String,
                name: String?,
                usedSpace: Double,
                currency: String,
                credit: Int,
                maxSpace: Double,
                maxUpload: Double,
                role: Int,
                private: Int,
                subscribed: Subscribed,
                services: Int,
                delinquent: Int,
                orgPrivateKey: String?,
                email: String?,
                displayName: String?,
                keys: [Key]) {
        self.ID = ID
        self.name = name
        self.usedSpace = usedSpace
        self.currency = currency
        self.credit = credit
        self.maxSpace = maxSpace
        self.maxUpload = maxUpload
        self.role = role
        self.private = `private`
        self.subscribed = subscribed
        self.services = services
        self.delinquent = delinquent
        self.orgPrivateKey = orgPrivateKey
        self.email = email
        self.displayName = displayName
        self.keys = keys
    }
}

@objc(UserInfo)
public final class UserInfo: NSObject {
    public var attachPublicKey: Int
    public var autoSaveContact: Int
    public var conversationToolbarActions: ToolbarActions
    public var crashReports: Int
    public var credit: Int
    public var currency: String
    public var defaultSignature: String
    public var delaySendSeconds: Int
    public var delinquent: Int
    public var displayName: String
    public var enableFolderColor: Int
    /// 0 - threading, 1 - single message
    public var groupingMode: Int
    public var hideEmbeddedImages: Int
    public var hideRemoteImages: Int
    public var imageProxy: ImageProxy
    public var inheritParentFolderColor: Int
    public var language: String
    public var linkConfirmation: LinkOpeningMode
    public var listToolbarActions: ToolbarActions
    public var maxSpace: Int64
    public var maxUpload: Int64
    public var messageToolbarActions: ToolbarActions
    public var notificationEmail: String
    public var notify: Int
    public var passwordMode: Int
    public var referralProgram: ReferralProgram?
    public var role: Int
    public var sign: Int
    /// 0: free user, > 0: paid user
    public var subscribed: User.Subscribed
    public var swipeLeft: Int
    public var swipeRight: Int
    public var telemetry: Int
    public var twoFactor: Int
    public var usedSpace: Int64
    public var userAddresses: [Address]
    public var userId: String
    public var userKeys: [Key]
    public var weekStart: Int

    public static func getDefault() -> UserInfo {
        return .init(maxSpace: 0, usedSpace: 0, language: "",
                     maxUpload: 0, role: 0, delinquent: 0,
                     keys: nil, userId: "", linkConfirmation: 0,
                     credit: 0, currency: "", subscribed: DefaultValue.subscribed)
    }

    // init from cache
    public required init(
        displayName: String?,
        hideEmbeddedImages: Int?,
        hideRemoteImages: Int?,
        imageProxy: Int?,
        maxSpace: Int64?,
        notificationEmail: String?,
        signature: String?,
        usedSpace: Int64?,
        userAddresses: [Address]?,
        autoSC: Int?,
        language: String?,
        maxUpload: Int64?,
        notify: Int?,
        swipeLeft: Int?,
        swipeRight: Int?,
        role: Int?,
        delinquent: Int?,
        keys: [Key]?,
        userId: String?,
        sign: Int?,
        attachPublicKey: Int?,
        linkConfirmation: String?,
        credit: Int?,
        currency: String?,
        pwdMode: Int?,
        twoFA: Int?,
        enableFolderColor: Int?,
        inheritParentFolderColor: Int?,
        subscribed: User.Subscribed?,
        groupingMode: Int?,
        weekStart: Int?,
        delaySendSeconds: Int?,
        telemetry: Int?,
        crashReports: Int?,
        conversationToolbarActions: ToolbarActions?,
        messageToolbarActions: ToolbarActions?,
        listToolbarActions: ToolbarActions?,
        referralProgram: ReferralProgram?)
    {
        self.maxSpace = maxSpace ?? DefaultValue.maxSpace
        self.usedSpace = usedSpace ?? DefaultValue.usedSpace
        self.language = language ?? DefaultValue.language
        self.maxUpload = maxUpload ?? DefaultValue.maxUpload
        self.role = role ?? DefaultValue.role
        self.delinquent = delinquent ?? DefaultValue.delinquent
        self.userKeys = keys ?? DefaultValue.userKeys
        self.userId = userId ?? DefaultValue.userId

        // get from user settings
        self.crashReports = crashReports ?? DefaultValue.crashReports
        self.credit = credit ?? DefaultValue.credit
        self.currency = currency ?? DefaultValue.currency
        self.enableFolderColor = enableFolderColor ?? DefaultValue.enableFolderColor
        self.inheritParentFolderColor = inheritParentFolderColor ?? DefaultValue.inheritParentFolderColor
        self.notificationEmail = notificationEmail ?? DefaultValue.notificationEmail
        self.notify = notify ?? DefaultValue.notify
        self.passwordMode = pwdMode ?? DefaultValue.passwordMode
        self.subscribed = subscribed ?? DefaultValue.subscribed
        self.telemetry = telemetry ?? DefaultValue.telemetry
        self.twoFactor = twoFA ?? DefaultValue.twoFactor
        self.userAddresses = userAddresses ?? DefaultValue.userAddresses
        self.weekStart = weekStart ?? DefaultValue.weekStart

        // get from mail settings
        self.attachPublicKey = attachPublicKey ?? DefaultValue.attachPublicKey
        self.autoSaveContact  = autoSC ?? DefaultValue.autoSaveContact
        self.defaultSignature = signature ?? DefaultValue.defaultSignature
        self.delaySendSeconds = delaySendSeconds ?? DefaultValue.delaySendSeconds
        self.displayName = displayName ?? DefaultValue.displayName
        self.groupingMode = groupingMode ?? DefaultValue.groupingMode
        self.hideEmbeddedImages = hideEmbeddedImages ?? DefaultValue.hideEmbeddedImages
        self.hideRemoteImages = hideRemoteImages ?? DefaultValue.hideRemoteImages
        self.imageProxy = imageProxy.map(ImageProxy.init(rawValue:)) ?? DefaultValue.imageProxy
        self.sign = sign ?? DefaultValue.sign
        self.swipeLeft = swipeLeft ?? DefaultValue.swipeLeft
        self.swipeRight = swipeRight ?? DefaultValue.swipeRight
        if let value = linkConfirmation, let mode = LinkOpeningMode(rawValue: value) {
            self.linkConfirmation = mode
        } else {
            self.linkConfirmation = DefaultValue.linkConfirmation
        }
        self.conversationToolbarActions = conversationToolbarActions ?? DefaultValue.conversationToolbarActions
        self.messageToolbarActions = messageToolbarActions ?? DefaultValue.messageToolbarActions
        self.listToolbarActions = listToolbarActions ?? DefaultValue.listToolbarActions
        self.referralProgram = referralProgram
    }

    // init from api
    public required init(maxSpace: Int64?,
                         usedSpace: Int64?,
                         language: String?,
                         maxUpload: Int64?,
                         role: Int?,
                         delinquent: Int?,
                         keys: [Key]?,
                         userId: String?,
                         linkConfirmation: Int?,
                         credit: Int?,
                         currency: String?,
                         subscribed: User.Subscribed?) {
        self.attachPublicKey = DefaultValue.attachPublicKey
        self.autoSaveContact = DefaultValue.autoSaveContact
        self.conversationToolbarActions = DefaultValue.conversationToolbarActions
        self.crashReports = DefaultValue.crashReports
        self.credit = credit ?? DefaultValue.credit
        self.currency = currency ?? DefaultValue.currency
        self.defaultSignature = DefaultValue.defaultSignature
        self.delaySendSeconds = DefaultValue.delaySendSeconds
        self.delinquent = delinquent ?? DefaultValue.delinquent
        self.displayName = DefaultValue.displayName
        self.enableFolderColor = DefaultValue.enableFolderColor
        self.groupingMode = DefaultValue.groupingMode
        self.hideEmbeddedImages = DefaultValue.hideEmbeddedImages
        self.hideRemoteImages = DefaultValue.hideRemoteImages
        self.imageProxy = DefaultValue.imageProxy
        self.inheritParentFolderColor = DefaultValue.inheritParentFolderColor
        self.language = language ?? DefaultValue.language
        self.linkConfirmation = linkConfirmation == 0 ? .openAtWill : DefaultValue.linkConfirmation
        self.listToolbarActions = DefaultValue.listToolbarActions
        self.maxSpace = maxSpace ?? DefaultValue.maxSpace
        self.maxUpload = maxUpload ?? DefaultValue.maxUpload
        self.messageToolbarActions = DefaultValue.messageToolbarActions
        self.notificationEmail = DefaultValue.notificationEmail
        self.notify = DefaultValue.notify
        self.passwordMode = DefaultValue.passwordMode
        self.role = role ?? DefaultValue.role
        self.sign = DefaultValue.sign
        self.subscribed = subscribed ?? DefaultValue.subscribed
        self.swipeLeft = DefaultValue.swipeLeft
        self.swipeRight = DefaultValue.swipeRight
        self.telemetry = DefaultValue.telemetry
        self.twoFactor = DefaultValue.twoFactor
        self.usedSpace = usedSpace ?? DefaultValue.usedSpace
        self.userAddresses = DefaultValue.userAddresses
        self.userId = userId ?? DefaultValue.userId
        self.userKeys = keys ?? DefaultValue.userKeys
        self.weekStart = DefaultValue.weekStart
    }

    /// Update user addresses
    ///
    /// - Parameter addresses: new addresses
    public func set(addresses: [Address]) {
        self.userAddresses = addresses
    }

    /// set User, copy the data from input user object
    ///
    /// - Parameter userinfo: New user info
    public func set(userinfo: UserInfo) {
        self.delinquent = userinfo.delinquent
        self.language = userinfo.language
        self.linkConfirmation = userinfo.linkConfirmation
        self.maxSpace = userinfo.maxSpace
        self.maxUpload = userinfo.maxUpload
        self.role = userinfo.role
        self.subscribed = userinfo.subscribed
        self.usedSpace = userinfo.usedSpace
        self.userId = userinfo.userId
        self.userKeys = userinfo.userKeys
    }
}

// exposed interfaces
extension UserInfo {

    public var isPaid: Bool {
        return self.role > 0 ? true : false
    }

    public func firstUserKey() -> Key? {
        if self.userKeys.count > 0 {
            return self.userKeys[0]
        }
        return nil
    }

    public func getPrivateKey(by keyID: String?) -> String? {
        if let keyID = keyID {
            for userkey in self.userKeys where userkey.keyID == keyID {
                return userkey.privateKey
            }
        }
        return firstUserKey()?.privateKey
    }

    public var isKeyV2: Bool {
        return addressKeys.isKeyV2
    }

    /// TODO:: fix me - Key stuff
    public var addressKeys: [Key] {
        var out = [Key]()
        for addr in userAddresses {
            for key in addr.keys {
                out.append(key)
            }
        }
        return out
    }

    public func getAddressPrivKey(address_id: String) -> String {
        let addr = userAddresses.address(byID: address_id) ?? userAddresses.defaultSendAddress()
        return addr?.keys.first?.privateKey ?? ""
    }

    public func getAddressKey(address_id: String) -> Key? {
        let addr = userAddresses.address(byID: address_id) ?? userAddresses.defaultSendAddress()
        return addr?.keys.first
    }

    /// Get all keys that belong to the given address id
    /// - Parameter address_id: Address id
    /// - Returns: Keys of the given address id. nil means can't find the address
    public func getAllAddressKey(address_id: String) -> [Key]? {
        guard let addr = userAddresses.address(byID: address_id) else {
            return nil
        }
        return addr.keys
    }
}

// MARK: Default values

extension UserInfo {
    struct DefaultValue {
        static let attachPublicKey: Int = 0
        static let autoSaveContact: Int = 0
        static let crashReports: Int = 1
        static let credit: Int = 0
        static let currency: String = "USD"
        static let defaultSignature: String = ""
        static let delaySendSeconds: Int = 10
        static let delinquent: Int = 0
        static let displayName: String = ""
        static let enableFolderColor: Int = 0
        static let groupingMode: Int = 0
        static let hideEmbeddedImages: Int = 1
        static let hideRemoteImages: Int = 0
        static let imageProxy: ImageProxy = .imageProxy
        static let inheritParentFolderColor: Int = 0
        static let language: String = "en_US"
        static let linkConfirmation: LinkOpeningMode = .confirmationAlert
        static let maxSpace: Int64 = 0
        static let maxUpload: Int64 = 0
        static let notificationEmail: String = ""
        static let notify: Int = 0
        static let passwordMode: Int = 1
        static let role: Int = 0
        static let sign: Int = 0
        static let subscribed: User.Subscribed = .init(rawValue: 0)
        static let swipeLeft: Int = 3
        static let swipeRight: Int = 0
        static let telemetry: Int = 1
        static let twoFactor: Int = 0
        static let usedSpace: Int64 = 0
        static let userAddresses: [Address] = []
        static let userId: String = ""
        static let userKeys: [Key] = []
        static let weekStart: Int = 0
        static let conversationToolbarActions: ToolbarActions = .init(isCustom: false, actions: [])
        static let messageToolbarActions: ToolbarActions = .init(isCustom: false, actions: [])
        static let listToolbarActions: ToolbarActions = .init(isCustom: false, actions: [])
    }
}
