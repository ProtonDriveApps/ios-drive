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
import FileProviderUI

public enum CrossProcessErrorExchange {
    public static let UnderlyingMessageKey = "UnderlyingMessageKey"
    
    public static let notAuthenticated = "notAuthenticated"
    public static let childSessionExpired = "childSessionExpired"
    public static let pinExchangeInProgress = "pinExchangeInProgress"
    public static let pinExchangeNotSupported = "pinExchangeNotSupported"
    
    public static let pinExchangeNotSupportedError = NSFileProviderError(.notAuthenticated, userInfo: [UnderlyingMessageKey: pinExchangeNotSupported])
    
    public static let pinExchangeInProgressError = NSFileProviderError(.notAuthenticated, userInfo: [UnderlyingMessageKey: pinExchangeInProgress])
    
    public static let notAuthenticatedError = NSFileProviderError(.notAuthenticated, userInfo: [UnderlyingMessageKey: notAuthenticated])
    
    public static let childSessionExpiredError = NSFileProviderError(.notAuthenticated, userInfo: [UnderlyingMessageKey: childSessionExpired])
    
    public static let cancelError = NSError(domain: FPUIErrorDomain,
                                            code: Int(FPUIExtensionErrorCode.failed.rawValue),
                                            userInfo: nil)
}
#endif
