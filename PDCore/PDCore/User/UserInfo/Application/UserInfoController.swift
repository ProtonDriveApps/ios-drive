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

public protocol UserInfoController {
    var userInfo: AnyPublisher<UserInfo?, Never> { get }
}

final class UpdatingUserInfoController: UserInfoController {
    private let resource: UserInfoResource
    private var subject: CurrentValueSubject<UserInfo?, Never>
    private var cancellables = Set<AnyCancellable>()

    var userInfo: AnyPublisher<UserInfo?, Never> {
        subject.eraseToAnyPublisher()
    }

    init(resource: UserInfoResource) {
        self.resource = resource
        subject = .init(resource.getUserInfo())
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        resource.userInfoPublisher
            .sink { [weak self] userInfo in
                self?.subject.send(userInfo)
            }
            .store(in: &cancellables)
    }
}
