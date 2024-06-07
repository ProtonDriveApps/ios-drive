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

public struct UserSettings: Codable, Equatable {
    
    enum CodingKeys: String, CodingKey {
        case password
        case twoFA = "_2FA" // required for .decapitaliseFirstLetter in ProtonCoreUtilities
        case news
        case locale
        case logAuth
        case invoiceText
        case density
        case theme
        case themeType
        case weekStart
        case dateFormat
        case timeFormat
        case welcome
        case welcomeFlag
        case earlyAccess
        case flags
        case referral
        case telemetry
        case passwordMode
        case deviceRecovery
        case crashReports
        case totp = "TOTP"
    }
    
    public let password: Password
    public let twoFA: TwoFA
    public let news: Int
    public let locale: String
    public let logAuth: Int
    public let invoiceText: String
    public let density: Int
    public let theme: String?
    public let themeType: Int
    public let weekStart: Int
    public let dateFormat: Int
    public let timeFormat: Int
    public let welcome: Int
    public let welcomeFlag: Int
    public let earlyAccess: Int
    public let flags: Flags
    public let referral: Referral
    public let telemetry: Int
    public let crashReports: Int
    public let passwordMode: Int
    public let deviceRecovery: Int
    public let totp: Int
    
    public init(password: Password, twoFA: TwoFA, news: Int, locale: String, logAuth: Int, invoiceText: String, density: Int, theme: String?, themeType: Int, weekStart: Int, dateFormat: Int, timeFormat: Int, welcome: Int, welcomeFlag: Int, earlyAccess: Int, flags: Flags, referral: Referral, telemetry: Int, crashReports: Int, passwordMode: Int, deviceRecovery: Int, totp: Int) {
        self.password = password
        self.twoFA = twoFA
        self.news = news
        self.locale = locale
        self.logAuth = logAuth
        self.invoiceText = invoiceText
        self.density = density
        self.theme = theme
        self.themeType = themeType
        self.weekStart = weekStart
        self.dateFormat = dateFormat
        self.timeFormat = timeFormat
        self.welcome = welcome
        self.welcomeFlag = welcomeFlag
        self.earlyAccess = earlyAccess
        self.flags = flags
        self.referral = referral
        self.telemetry = telemetry
        self.crashReports = crashReports
        self.passwordMode = passwordMode
        self.deviceRecovery = deviceRecovery
        self.totp = totp
    }

}
