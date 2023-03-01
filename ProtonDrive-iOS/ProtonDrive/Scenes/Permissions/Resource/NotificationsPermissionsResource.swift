//
//  LocalNotificationPermissionsResource.swift
//  ProtonDrive
//
//  Created by Jan Halousek on 02.02.2023.
//  Copyright © 2023 ProtonMail. All rights reserved.
//

import Combine
import UserNotifications

protocol LocalNotificationPermissionsResource {
    func isRequestable() -> AnyPublisher<Bool, Never>
    func requestPermissions() -> AnyPublisher<Void, Never>
}

final class UNUserNotificationPermisionsResource: LocalNotificationPermissionsResource {
    func isRequestable() -> AnyPublisher<Bool, Never> {
        Future<Bool, Never> { promise in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                let isRequestable = settings.authorizationStatus == .notDetermined
                promise(.success(isRequestable))
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    func requestPermissions() -> AnyPublisher<Void, Never> {
        Future<Void, Never> { promise in
            let center = UNUserNotificationCenter.current()
            center.requestAuthorization(options: [.alert]) { _, _ in
                promise(.success)
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
}
