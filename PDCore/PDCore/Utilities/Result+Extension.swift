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

extension Result where Success: File, Failure: Error {
    func sendNotificationIfFailure(with name: Notification.Name) {
        if case Result.failure(let error) = self {
            NotificationCenter.default.post(name: name, object: self, userInfo: ["Error": error])
        }
    }
}

extension Notification {
    func unpackFailure() -> Error? {
        self.userInfo?["Error"] as? Error
    }
}

extension NotificationCenter {
    func throwIfFailure<Value>(with name: Notification.Name) -> AnyPublisher<[Value], Error> {
        self.publisher(for: name)
        .setFailureType(to: Error.self)
        .compactMap { $0.unpackFailure() }
        .tryMap { throw $0 }
        .map { [] }
        .eraseToAnyPublisher()
    }
}
