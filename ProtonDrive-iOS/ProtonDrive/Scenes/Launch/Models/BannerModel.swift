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
import ProtonCore_UIFoundations

final class BannerModel {
    let delay: Delay
    let message: String
    let style: PMBannerNewStyle

    init(message: String, style: PMBannerNewStyle, delay: Delay = .immediate) {
        self.style = style
        self.message = message
        self.delay = delay
    }

    enum Delay {
        case immediate
        case delayed
    }

    static func success(_ message: String, delay: Delay = .immediate) -> BannerModel {
        BannerModel(message: message, style: .success, delay: delay)
    }

    static func failure(_ error: Error, delay: Delay = .immediate) -> BannerModel {
        BannerModel(message: error.localizedDescription, style: .error, delay: delay)
    }

    static func warning(_ message: String) -> BannerModel {
        BannerModel(message: message, style: .warning)
    }

    static func info(_ message: String) -> BannerModel {
        BannerModel(message: message, style: .info)
    }
}

extension NSNotification.Name {
    static var banner: NSNotification.Name { NSNotification.Name("ProtonDrive.Banner") }
}

extension NotificationCenter {
    func postBanner(_ model: BannerModel) {
        post(name: .banner, object: model)
    }
}
