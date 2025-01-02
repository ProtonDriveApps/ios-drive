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
import Foundation
import PDCore

protocol PhotoUpsellFlowController {
    func updatePhotoTabVisible(isVisible: Bool)
}

final class ConcretePhotoUpsellFlowController: PhotoUpsellFlowController {
    private let coordinator: PhotoUpsellCoordinator
    private let localSettings: LocalSettings
    private let userInfoController: UserInfoController
    private let photoUploadedNotifier: PhotoUploadedNotifier
    private let notificationsPermissionsFlowController: NotificationsPermissionsFlowController
    private var cancellables: Set<AnyCancellable> = []
    private let photoUpsellResultNotifier: PhotoUpsellResultNotifierProtocol
    
    private var uploadedPhoto: Int = 0 {
        didSet { presentUpsellIfNeeded() }
    }
    private var isFreeUser: Bool = false {
        didSet { presentUpsellIfNeeded() }
    }
    private var isPhotoTabVisible: Bool = false {
        didSet { presentUpsellIfNeeded() }
    }
    private var isNotificationShownInThisSession = false
    private var isOneDollarUpsellShownInThisSession = false

    init(
        coordinator: PhotoUpsellCoordinator,
        photoUploadedNotifier: PhotoUploadedNotifier,
        localSettings: LocalSettings,
        userInfoController: UserInfoController,
        notificationsPermissionsFlowController: NotificationsPermissionsFlowController,
        photoUpsellResultNotifier: PhotoUpsellResultNotifierProtocol
    ) {
        self.coordinator = coordinator
        self.localSettings = localSettings
        self.userInfoController = userInfoController
        self.photoUploadedNotifier = photoUploadedNotifier
        self.notificationsPermissionsFlowController = notificationsPermissionsFlowController
        self.photoUpsellResultNotifier = photoUpsellResultNotifier
        subscribeUpdate()
    }
    
    private func subscribeUpdate() {
        photoUploadedNotifier.uploadedNotifier
            .sink { [weak self] _ in
                self?.uploadedPhoto += 1
            }
            .store(in: &cancellables)
        
        userInfoController.userInfo
            .sink { [weak self] userInfo in
                guard let self, let userInfo else { return }
                self.isFreeUser = !userInfo.isPaid
            }
            .store(in: &cancellables)
        
        notificationsPermissionsFlowController.event
            .sink { [weak self] event in
                #if DEBUG
                // when skipNotificationPermissions is existing, the popup won't be shown
                // but the event will be sent
                if DebugConstants.commandLineContains(flags: [.uiTests, .skipNotificationPermissions]) {
                    return
                }
                #endif
                if event == .close { return }
                self?.isNotificationShownInThisSession = true
            }
            .store(in: &cancellables)
        
        localSettings.publisher(for: \.isUpsellShown)
            .dropFirst()
            .sink { [weak self] isShown in
                guard isShown else { return }
                self?.isOneDollarUpsellShownInThisSession = true
            }
            .store(in: &cancellables)
    }
    
    private func shouldPresentUpsell() -> Bool {
        let shouldPresent = localSettings.showPhotoUpsellInNextLaunch ?? false
        let isConditionFulfill = shouldPresent || uploadedPhoto >= 5

        guard
            isFreeUser,
            isConditionFulfill,
            isPhotoTabVisible
        else { return false }

        guard
            !isNotificationShownInThisSession,
            !isOneDollarUpsellShownInThisSession
        else {
            localSettings.showPhotoUpsellInNextLaunch = true
            return false
        }
        
        return true
    }
    
    private func presentUpsellIfNeeded() {
        guard shouldPresentUpsell() else { return }
        localSettings.isPhotoUpsellShown = true
        localSettings.showPhotoUpsellInNextLaunch = false
        cancellables.removeAll()
        coordinator.openUpsellView(photoUpsellResultNotifier: photoUpsellResultNotifier)
    }
    
    func updatePhotoTabVisible(isVisible: Bool) {
        isPhotoTabVisible = isVisible
    }
}

#if DEBUG
struct PhotoUpsellFlowTestsManager {
    static func setFlagForUITest(localSettings: LocalSettings) {
        guard DebugConstants.commandLineContains(flags: [.uiTests]) else { return }
        
        if DebugConstants.commandLineContains(flags: [.defaultPhotoUpsell]) {
            localSettings.isPhotoUpsellShown = false
            DebugConstants.removeCommandLine(flags: [.defaultPhotoUpsell])
        }
        
        if DebugConstants.commandLineContains(flags: [.skipPhotoUpsell]) {
            localSettings.isPhotoUpsellShown = true
            DebugConstants.removeCommandLine(flags: [.skipPhotoUpsell])
        }
    }
}
#endif
