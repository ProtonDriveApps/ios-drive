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

import Combine
import PDCore
import PDUIComponents
import SwiftUI
import ProtonCoreDataModel

protocol LockedStateTopBannerViewModelProtocol: ObservableObject {
    var data: LockedStateTopBannerViewData { get }
    func openUrl()
}

struct LockedStateTopBannerViewData: Equatable {
    let severance: WarningBadgeSeverance
    let title: String?
    let description: String?
    let actionButton: String?
    let buttonUrl: String?
}

final class LockedStateTopBannerViewModel: LockedStateTopBannerViewModelProtocol {
    
    @Published var data: LockedStateTopBannerViewData

    init(data: LockedStateTopBannerViewData) {
        self.data = data
    }
    
    convenience init(lockedStateBannerVisibiliy: LockedStateAlertVisibility) {
        let data = LockedStateTopBannerViewData(severance: .error,
                                                title: lockedStateBannerVisibiliy.bannerTitle,
                                                description: lockedStateBannerVisibiliy.bannerDescription,
                                                actionButton: lockedStateBannerVisibiliy.bannerButtonTitle,
                                                buttonUrl: lockedStateBannerVisibiliy.bannerButtonUrl)
        self.init(data: data)
    }
    
    func openUrl() {
        guard let urlString = self.data.buttonUrl, let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}
