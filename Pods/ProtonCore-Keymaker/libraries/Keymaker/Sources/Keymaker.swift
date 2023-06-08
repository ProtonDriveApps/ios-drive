//
//  Keymaker.swift
//  ProtonCore-ProtonCore-Keymaker - Created on 13/10/2018.
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
import EllipticCurveKeyPair

#if canImport(UIKit)
import UIKit
#endif

public enum Constants {
    public static let removedMainKeyFromMemory: NSNotification.Name = .init("Keymaker" + ".removedMainKeyFromMemory")
    public static let errorObtainingMainKey: NSNotification.Name = .init("Keymaker" + ".errorObtainingMainKey")
    public static let obtainedMainKey: NSNotification.Name = .init("Keymaker" + ".obtainedMainKey")
    public static let requestMainKey: NSNotification.Name = .init("Keymaker" + ".requestMainKey")
}

public typealias MainKey = [UInt8]

public class Keymaker: NSObject {
    public typealias Const = Constants
        
    private var autolocker: Autolocker?
    private let keychain: Keychain
    public init(autolocker: Autolocker?, keychain: Keychain) {
        self.autolocker = autolocker
        self.keychain = keychain
        
        super.init()
        #if canImport(UIKit)
        if #available(iOS 13.0, *) {
            NotificationCenter.default.addObserver(self, selector: #selector(mainKeyExists),
                                                   name: UIApplication.willEnterForegroundNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(mainKeyExists),
                                                   name: UIApplication.willEnterForegroundNotification, object: nil)
        } else {
            NotificationCenter.default.addObserver(self, selector: #selector(mainKeyExists),
                                                   name: UIApplication.willEnterForegroundNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(mainKeyExists),
                                                   name: UIApplication.didBecomeActiveNotification, object: nil)
        }
        #endif
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // stored in-memory value
    private var _mainKey: MainKey? {
        didSet {
            if _mainKey != nil {
                self.resetAutolock()
                self.setupCryptoTransformers(key: _mainKey)
            } else {
                NotificationCenter.default.post(name: Const.removedMainKeyFromMemory, object: self)
            }
        }
    }
    
    private var _key: MainKey? {
        didSet {
            if _key != nil {
                self.setupCryptoTransformers(key: _key)
            } else {
                NotificationCenter.default.post(name: Const.removedMainKeyFromMemory, object: self)
            }
        }
    }
    
    // accessor for stored value; if stored value is nill - calls provokeMainKeyObtention() method
    
    @available(*, deprecated, message: "this shouldn't be used after the migration and this will be private.")
    public var mainKey: MainKey? {
        privatelyAccessibleMainKey
    }

    private var privatelyAccessibleMainKey: MainKey? {
        if self.autolocker?.shouldAutolockNow() == true {
            self._mainKey = nil
        }
        if self._mainKey == nil, let newKey = self.provokeMainKeyObtention() {
            self._mainKey = newKey
        }
        return self._mainKey
    }
    
    public func mainKey(by protection: RandomPinProtection?) -> MainKey? {
        if self._mainKey != nil {
            return _mainKey
        }
        
        guard let protectionStrategy = protection else {
            return self.privatelyAccessibleMainKey
        }
        if self._key == nil, let newKey = self.obtainMainKeyBackground(with: protectionStrategy) {
            self._key = newKey
        }
        
        return self._key
    }
    
    // try to get mainkey from background, this will not always on main thread.
    public func obtainMainKeyBackground(with protector: RandomPinProtection) -> MainKey? {
        guard self._key == nil else {
            return self._key
        }
        
        guard let cypherBits = protector.getCypherBits() else {
            return nil
        }
        
        do {
            let mainKeyBytes = try protector.unlock(cypherBits: cypherBits)
            self._key = mainKeyBytes
        } catch {
            self._key = nil
        }
        return self._key
    }
    
    public func resetAutolock() {
        self.autolocker?.releaseCountdown()
    }
    
    // Try to get main key from storage if it exists, otherwise create one.
    // if there is any significant Protection active - post message that obtainMainKey(_:_:) is needed
    private func getMainKeyByRandomPin() -> MainKey? {
        // if we have any significant Protector - wait for obtainMainKey(_:_:) method to be called
        guard !self.isProtectorActive(RandomPinProtection.self) else {
            return nil
        }
        
        // if we have NoneProtection active - get the key right ahead
        if let cypherText = NoneProtection.getCypherBits(from: self.keychain) {
            do {
                return try NoneProtection(keychain: self.keychain).unlock(cypherBits: cypherText)
            } catch let error {
                fatalError(error.localizedDescription)
            }
        }
        
        // otherwise there is no saved mainKey at all, so we should generate a new one with default protection
        let newKey = self.generateNewMainKeyWithDefaultProtection()
        return newKey
    }
    
    // Try to get main key from storage if it exists, otherwise create one.
    // if there is any significant Protection active - post message that obtainMainKey(_:_:) is needed
    private func provokeMainKeyObtention() -> MainKey? {
        // if we have any significant Protector - wait for obtainMainKey(_:_:) method to be called
        guard !self.isProtectorActive(BioProtection.self),
            !self.isProtectorActive(PinProtection.self) else
        {
            NoneProtection.removeCyphertext(from: self.keychain)
            NotificationCenter.default.post(.init(name: Const.requestMainKey))
            return nil
        }
        
        // if we have NoneProtection active - get the key right ahead
        if let cypherText = NoneProtection.getCypherBits(from: self.keychain) {
            do {
                return try NoneProtection(keychain: self.keychain).unlock(cypherBits: cypherText)
            } catch let error {
                fatalError(error.localizedDescription)
            }
        }
        
        // otherwise there is no saved mainKey at all, so we should generate a new one with default protection
        let newKey = self.generateNewMainKeyWithDefaultProtection()
        return newKey
    }
    
    private let controlThread: OperationQueue = {
        let operation = OperationQueue()
        operation.maxConcurrentOperationCount = 1
        return operation
    }()
    
    public func wipeMainKey() {
        NoneProtection.removeCyphertext(from: self.keychain)
        BioProtection.removeCyphertext(from: self.keychain)
        PinProtection.removeCyphertext(from: self.keychain)
        
        self._mainKey = nil
        self._key = nil
        self.setupCryptoTransformers(key: nil)
    }
    
    @discardableResult @objc
    public func mainKeyExists() -> Bool { // cuz another process can wipe main key from memory while the app is in background
        if !self.isProtectorActive(BioProtection.self),
            !self.isProtectorActive(PinProtection.self),
            !self.isProtectorActive(NoneProtection.self)
        {
            self._mainKey = nil
            NotificationCenter.default.post(.init(name: Const.requestMainKey))
            return false
        }
        if self.privatelyAccessibleMainKey != nil {
            self.resetAutolock()
        }
        return true
    }
    
    public func lockTheApp() {
        self._mainKey = nil
    }
    
    /// Assigns in-memory decrypted MainKey value, typically obtained externally, skipping all obtaination flows.
    /// Does not check correctness of MainKey, does not send any notifications or messages.
    /// **Important: use only for cross-process transfers of MainKey.**
    ///
    /// *Usecase example:*
    /// ProtonDrive File Provider appex has two processes - FileProvider runs in the background and performs operations on files, and FileProviderUI is able to present UI but can not perform operations.
    /// When the app has significant protections enabled, we would present FileProviderUI and user will obtain MainKey by usual flow.
    /// Then MainKey needs to be transferred to FileProvider process (solved by Drive team) and needs to be injected into its Keymaker instance (by means of ``GenericKeymaker/forceInjectMainKey(_:)``).
    ///
    public func forceInjectMainKey(_ potentialMainKey: MainKey) {
        self._mainKey = potentialMainKey
    }
    
    public func obtainMainKey(with protector: ProtectionStrategy,
                              handler: @escaping (MainKey?) -> Void)
    {
        // usually calling a method developers assume to get the callback on the same thread,
        // so for ease of use (and since most of callbacks turned out to work with UI)
        // we'll return to main thread explicitly here
        let isMainThread = Thread.current.isMainThread
        
        self.controlThread.addOperation {
            guard self._mainKey == nil else {
                isMainThread ? DispatchQueue.main.async { handler(self._mainKey) } : handler(self._mainKey)
                return
            }
            
            guard let cypherBits = protector.getCypherBits() else {
                isMainThread ? DispatchQueue.main.async { handler(nil) } : handler(nil)
                return
            }
            
            do {
                let mainKeyBytes = try protector.unlock(cypherBits: cypherBits)
                self._mainKey = mainKeyBytes
                NotificationCenter.default.post(name: Const.obtainedMainKey, object: self)
            } catch let error {
                NotificationCenter.default.post(name: Const.errorObtainingMainKey, object: self, userInfo: ["error": error])
                
                if #available(iOS 14.0, *) {
                    self._mainKey = nil
                }
                // this CFError trows randomly on iOS 13 (up to 13.3 beta 2) on TouchID capable devices
                // it happens less if auth prompt is invoked with 1 sec delay after app gone foreground but still happens
                // description: "Could not decrypt. Failed to get externalizedContext from LAContext"
                else if #available(iOS 13.0, *),
                        case EllipticCurveKeyPair.Error.underlying(message: _, error: let underlyingError) = error,
                        underlyingError.code == -2
                {
                    isMainThread
                        ? DispatchQueue.main.async { self.obtainMainKey(with: protector, handler: handler) }
                        : self.obtainMainKey(with: protector, handler: handler)
                } else {
                    self._mainKey = nil
                }
            }
            
            isMainThread ? DispatchQueue.main.async { handler(self._mainKey) } : handler(self._mainKey)
        }
    }
    
    // completion says whether protector was activated or not
    public func activate(_ protector: ProtectionStrategy,
                         completion: @escaping (Bool) -> Void)
    {
        let isMainThread = Thread.current.isMainThread
        self.controlThread.addOperation {
            guard let mainKey = self.privatelyAccessibleMainKey,
                  (try? protector.lock(value: mainKey)) != nil else
            {
                isMainThread ? DispatchQueue.main.async { completion(false) } : completion(false)
                return
            }
            
            // we want to remove unprotected value from storage if the new Protector is significant
            if !(protector is NoneProtection) {
                self.deactivate(NoneProtection(keychain: self.keychain))
            }
            
            isMainThread ? DispatchQueue.main.async { completion(true) } : completion(true)
        }
    }
    
    public func isProtectorActive<T: ProtectionStrategy>(_ protectionType: T.Type) -> Bool {
        return protectionType.getCypherBits(from: self.keychain) != nil
    }
    
    @discardableResult public func deactivate(_ protector: ProtectionStrategy) -> Bool {
        protector.removeCyphertextFromKeychain()
        
        if protector is RandomPinProtection {
            self._key = nil
        }
        
        // need to keep mainKey in keychain in case user switches off all the significant Protectors
        if !self.isProtectorActive(BioProtection.self),
            !self.isProtectorActive(PinProtection.self)
        {
            self._key = nil
            self.activate(NoneProtection(keychain: self.keychain), completion: { _ in })
        }
        
        return true
    }
    
    private func generateNewMainKeyWithDefaultProtection() -> MainKey {
        self.wipeMainKey() // get rid of all old protected mainKeys
        let newMainKey = NoneProtection.generateRandomValue(length: 32)
        do {
            try NoneProtection(keychain: self.keychain).lock(value: newMainKey)
        } catch let error {
            fatalError(error.localizedDescription)
        }
        return newMainKey
    }
    
    private func setupCryptoTransformers(key: MainKey?) {
        guard let key = key else {
            ValueTransformer.setValueTransformer(nil, forName: .init(rawValue: "StringCryptoTransformer"))
            return
        }
        ValueTransformer.setValueTransformer(StringCryptoTransformer(key: key),
                                             forName: .init(rawValue: "StringCryptoTransformer"))
    }
    
    public func updateAutolockCountdownStart() {
        self.autolocker?.startCountdown()
        _ = self.privatelyAccessibleMainKey
    }
}
