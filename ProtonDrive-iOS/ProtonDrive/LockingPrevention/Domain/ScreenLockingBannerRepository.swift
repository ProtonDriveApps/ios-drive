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

import Combine
import PDCore

public protocol ScreenLockingBannerRepository {
    var isLockBannerEnabled: AnyPublisher<Bool, Never> { get }

    func disableLockBanner()
}

final class InMemoryScreenLockingBannerRepository: ScreenLockingBannerRepository {
    private let localSettings: LocalSettings
    private var isBannerEnabledSubject: CurrentValueSubject<Bool, Never>
    
    init(localSettings: LocalSettings) {
        self.localSettings = localSettings
        let bannerHasDismissed = localSettings.keepScreenAwakeBannerHasDismissed ?? false
        self.isBannerEnabledSubject = .init(!bannerHasDismissed)
    }

    var isLockBannerEnabled: AnyPublisher<Bool, Never> {
        isBannerEnabledSubject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    func disableLockBanner() {
        isBannerEnabledSubject.send(false)
        localSettings.keepScreenAwakeBannerHasDismissed = true
    }
}
