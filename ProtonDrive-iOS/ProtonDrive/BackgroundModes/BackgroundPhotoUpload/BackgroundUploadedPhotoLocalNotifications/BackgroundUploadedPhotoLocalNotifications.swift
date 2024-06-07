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
import UserNotifications
import PDCore

final class BackgroundUploadedPhotoLocalNotifications {
    private var cancellables = Set<AnyCancellable>()
    private let computationAvailability: ComputationalAvailabilityController

    private var showLocalNotification = false

    init(computationAvailability: ComputationalAvailabilityController, hasUploadedPhotoNotificationEnabled: Bool) {
        self.computationAvailability = computationAvailability

        guard hasUploadedPhotoNotificationEnabled else { return }

        computationAvailability.availability
            .sink { [weak self] availability in
                Log.info("📢 computationAvailability.availability: \(availability)", domain: .photosProcessing)
                switch availability {
                case .processingTask:
                    self?.showLocalNotification = true
                default:
                    self?.showLocalNotification = false
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .didUploadPhoto)
            .filter { [weak self] _ in self?.showLocalNotification ?? false }
            .sink(receiveValue: { [weak self] _ in
                self?.postLocalNotification()
            })
            .store(in: &cancellables)
    }

    private func postLocalNotification() {
        #if HAS_QA_FEATURES
        let content = UNMutableNotificationContent()
        content.title = "Proton Drive"
        content.body = "Did upload new photo 📸."

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: .leastNonzeroMagnitude, repeats: false)

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        #endif
    }

}
