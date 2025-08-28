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
import Combine

extension NotificationCenter {
    public func getPublisher<T>(for name: Notification.Name, publishing type: T.Type) -> AnyPublisher<T, Never> {
        publisher(for: name)
            .compactMap { notification in
                return notification.object as? T
            }
            .eraseToAnyPublisher()
    }

    public func getPublisher<T, S>(for name: Notification.Name, publishing type: T.Type, on scheduler: S) -> AnyPublisher<T, Never> where S: Scheduler {
        publisher(for: name)
            .compactMap { notification in
                return notification.object as? T
            }
            .receive(on: scheduler)
            .eraseToAnyPublisher()
    }

    public func getPublisher(for name: Notification.Name) -> AnyPublisher<Void, Never> {
        publisher(for: name)
            .compactMap { notification in
                return notification.object as? Void
            }
            .eraseToAnyPublisher()
    }
}

extension NotificationCenter {
    public func post(name aName: NSNotification.Name) {
        post(name: aName, object: Void())
    }
    
    public func nukeCache(reason: String) {
        post(name: .nukeCache, object: nil, userInfo: ["reason": reason])
    }
}
