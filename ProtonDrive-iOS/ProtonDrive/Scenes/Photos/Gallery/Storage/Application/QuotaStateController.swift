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

enum QuotaState {
    case fiftyPercentFull
    case eightyPercentFull
    case full
}

protocol QuotaStateController {
    var state: AnyPublisher<QuotaState?, Never> { get }
}

final class UserQuotaStateController: QuotaStateController {
    private let resource: QuotaResource
    private let subject = CurrentValueSubject<QuotaState?, Never>(nil)
    private var cancellables = Set<AnyCancellable>()

    var state: AnyPublisher<QuotaState?, Never> {
        subject.eraseToAnyPublisher()
    }

    init(resource: QuotaResource) {
        self.resource = resource
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
        if quota.available < Constants.minimalSpaceForAllowingUpload {
            return QuotaState.full
        } else if ratio > 0.8 {
            return QuotaState.eightyPercentFull
        } else if ratio >= 0.5 && !quota.isPaid {
            // Show fifty percent only to free users
            return QuotaState.fiftyPercentFull
        } else {
            return nil
        }
    }
}
