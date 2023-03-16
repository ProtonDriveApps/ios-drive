//
//  LocalNotificationsResource.swift
//  ProtonDrive
//
//  Created by Jan Halousek on 02.02.2023.
//  Copyright © 2023 ProtonMail. All rights reserved.
//

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
            identifier: localNotification.id.uuidString,
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
