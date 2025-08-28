// Copyright (c) 2025 Proton AG
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
import ProtonCoreUIFoundations

public final class BannerModel {
    public let delay: Delay
    public let message: String
    public let style: PMBannerNewStyle

    public init(message: String, style: PMBannerNewStyle, delay: Delay = .immediate) {
        self.style = style
        self.message = message
        self.delay = delay
    }

    public enum Delay {
        case immediate
        case delayed
    }

    public static func success(_ message: String, delay: Delay = .immediate) -> BannerModel {
        BannerModel(message: message, style: .success, delay: delay)
    }

    public static func failure(_ error: Error, delay: Delay = .immediate) -> BannerModel {
        BannerModel(message: error.localizedDescription, style: .error, delay: delay)
    }

    public static func warning(_ message: String) -> BannerModel {
        BannerModel(message: message, style: .warning)
    }

    public static func info(_ message: String) -> BannerModel {
        BannerModel(message: message, style: .info)
    }
}

public extension NotificationCenter {
    func postBanner(_ model: BannerModel) {
        post(name: DriveNotification.banner.name, object: model)
    }
}
