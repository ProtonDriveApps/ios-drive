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

import ProtonCoreUIFoundations
import PDCore

final class UserMessageHandler: UserMessageHandlerProtocol {
    func handleError(_ error: LocalizedError) {
        let model = BannerModel(message: error.localizedDescription, style: .error)
        NotificationCenter.default.postBanner(model)
    }

    func handleSuccess(_ message: String) {
        let model = BannerModel(message: message, style: .success)
        NotificationCenter.default.postBanner(model)
    }
}