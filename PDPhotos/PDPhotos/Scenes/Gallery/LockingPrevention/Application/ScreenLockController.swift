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

public protocol ScreenLockController {
    var shouldShowBanner: AnyPublisher<Bool, Never> { get }
    func setVisible(_ isVisible: Bool)
    func disable()
}

public class PhotosUploadingScreenLockController: ScreenLockController {
    private let backupNotifier: WorkingNotifier
    private let tagMigrationNotifier: WorkingNotifier
    private let lockingResource: ScreenLockingResource
    private let visibilityRepository: ScreenLockingBannerRepository
    private let isPhotoGalleryVisible = CurrentValueSubject<Bool, Never>(false)
    private var cancellables = Set<AnyCancellable>()
    private let shouldShowBannerSubject = CurrentValueSubject<Bool, Never>(false)
    private let isLockingDisabledPublisher: AnyPublisher<Bool, Never>

    public var shouldShowBanner: AnyPublisher<Bool, Never> {
        shouldShowBannerSubject.eraseToAnyPublisher()
    }

    public init(
        backupNotifier: WorkingNotifier,
        tagMigrationNotifier: WorkingNotifier,
        lockingResource: ScreenLockingResource,
        visibilityRepository: ScreenLockingBannerRepository
    ) {
        self.backupNotifier = backupNotifier
        self.tagMigrationNotifier = tagMigrationNotifier
        self.lockingResource = lockingResource
        self.visibilityRepository = visibilityRepository

        isLockingDisabledPublisher = backupNotifier.isWorkingPublisher
            .combineLatest(tagMigrationNotifier.isWorkingPublisher, isPhotoGalleryVisible)
            .map { ($0 || $1) && $2 }
            .removeDuplicates()
            .eraseToAnyPublisher()

        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        isLockingDisabledPublisher
            .sink { [weak self] isLockingDisabled in
                Log.info("Screen locking idle timer is: \(isLockingDisabled ? "disabled" : "enabled")", domain: .photosUI)
                self?.lockingResource.isIdleTimerDisabled = isLockingDisabled
            }
            .store(in: &cancellables)

        isLockingDisabledPublisher.combineLatest(visibilityRepository.isLockBannerEnabled)
            .sink { [weak self] isLockingDisabled, isBannerEnabled in
                self?.shouldShowBannerSubject.send(isLockingDisabled && isBannerEnabled)
            }
            .store(in: &cancellables)
    }

    public func setVisible(_ isVisible: Bool) {
        isPhotoGalleryVisible.send(isVisible)
    }

    public func disable() {
        visibilityRepository.disableLockBanner()
    }

    deinit {
        isPhotoGalleryVisible.send(false)
    }
}
