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
import ProtonCoreFeatureFlags

protocol OnboardingObserverProtocol {
    func startToObserveIsOnboardedStatus()
}

final class OnboardingObserver: OnboardingObserverProtocol {
    private let localSettings: LocalSettings
    private let notificationServiceOwner: hasPushNotificationService?
    private let userId: String?
    private var cancellables = Set<AnyCancellable>()
    /// For unit test
    var registerNotificationCompletion: (() -> Void)?
    
    init(
        localSettings: LocalSettings,
        notificationServiceOwner: hasPushNotificationService?,
        userId: String?
    ) {
        self.localSettings = localSettings
        self.notificationServiceOwner = notificationServiceOwner
        self.userId = userId
    }
    
    func startToObserveIsOnboardedStatus() {
        localSettings.publisher(for: \.isOnboarded)
            .combineLatest(localSettings.publisher(for: \.pushNotificationIsEnabled))
            .map { $0 && $1 }
            .removeDuplicates()
            .sink { [weak self] isReady in
                guard isReady else { return }
                self?.registerNotification()
            }
            .store(in: &cancellables)
    }
    
    private func registerNotification() {
        guard let owner = notificationServiceOwner, let userId else {
            registerNotificationCompletion?()
            return
        }
        owner.pushNotificationService?.registerForRemoteNotifications(uid: userId)
        registerNotificationCompletion?()
    }
}
