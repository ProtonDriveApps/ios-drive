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
import UserNotifications

protocol LocalNotificationsResource {
    func isRequestable() -> AnyPublisher<Bool, Never>
    func requestPermissions() -> AnyPublisher<Void, Never>
    func isAuthorized() -> AnyPublisher<Bool, Never>
    func addRequest(with localNotification: LocalNotification)
}

final class UNUserNotificationsResource: LocalNotificationsResource {
    func isRequestable() -> AnyPublisher<Bool, Never> {
        return UNUserNotificationCenter.current().getNotificationSettings()
            .map { $0.authorizationStatus == .notDetermined }
            .eraseToAnyPublisher()
    }
    
    func requestPermissions() -> AnyPublisher<Void, Never> {
        Deferred {
            Future { promise in
                let center = UNUserNotificationCenter.current()
                center.requestAuthorization(options: [.alert]) { _, _ in
                    promise(.success)
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    func isAuthorized() -> AnyPublisher<Bool, Never> {
        return UNUserNotificationCenter.current().getNotificationSettings()
            .map { $0.isAuthorized() }
            .eraseToAnyPublisher()
    }
    
    func addRequest(with localNotification: LocalNotification) {
        let request = UNNotificationRequest(localNotification)
        UNUserNotificationCenter.current().add(request)
    }
}

private extension UNNotificationSettings {
    func isAuthorized() -> Bool {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined, .denied:
            return false
        @unknown default:
            return false
        }
    }
}

extension UNNotificationRequest {
    convenience init(_ localNotification: LocalNotification) {
        let content = UNMutableNotificationContent()
        content.title = localNotification.title
        content.body = localNotification.body
        content.threadIdentifier = localNotification.thread

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: localNotification.delay,
            repeats: false
        )

        self.init(
            identifier: localNotification.id,
            content: content,
            trigger: trigger
        )
    }
}

private extension UNUserNotificationCenter {
    func getNotificationSettings() -> AnyPublisher<UNNotificationSettings, Never> {
        Deferred {
            Future<UNNotificationSettings, Never> { promise in
                self.getNotificationSettings { settings in
                    promise(.success(settings))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
}
