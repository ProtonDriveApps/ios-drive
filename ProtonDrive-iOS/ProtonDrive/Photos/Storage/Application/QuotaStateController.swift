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
import PDPhotos

final class UserQuotaStateController: QuotaStateController {
    private let resource: QuotaResource
    private let setting: QuotaStateSettings
    private let subject = CurrentValueSubject<QuotaState?, Never>(nil)
    private var cancellables = Set<AnyCancellable>()

    var state: AnyPublisher<QuotaState?, Never> {
        subject.eraseToAnyPublisher()
    }

    init(resource: QuotaResource, setting: QuotaStateSettings) {
        self.resource = resource
        self.setting = setting
        if let quota = resource.getQuota() {
            subject.value = mapQuota(quota)
        }
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        resource.availableQuotaPublisher
            .map { [weak self] quota in
                self?.mapQuota(quota)
            }
            .removeDuplicates()
            .sink { [weak self] state in
                self?.subject.send(state)
            }
            .store(in: &cancellables)
    }

    private func mapQuota(_ quota: Quota) -> QuotaState? {
        let ratio = Double(quota.used) / Double(quota.total)
        let state: QuotaState?
        if quota.available < Constants.Photos.minimalSpaceForAllowingUpload {
            state = QuotaState.full
        } else if ratio > 0.8 {
            state = QuotaState.eightyPercentFull
        } else if ratio >= 0.5 && quota.total < Constants.Photos.maximalSpaceForShowingQuotaWarning {
            // Show fifty percent only to users with small total space.
            state = QuotaState.fiftyPercentFull
        } else {
            state = nil
        }
        if state == setting.quotaState, state != .full {
            return nil
        } else {
            return state
        }
    }

    func remindLater() {
        setting.quotaState = subject.value
        subject.send(nil)
    }
}
