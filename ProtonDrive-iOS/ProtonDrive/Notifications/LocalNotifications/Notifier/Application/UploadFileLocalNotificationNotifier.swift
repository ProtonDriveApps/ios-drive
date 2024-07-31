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

import Foundation
import Combine
import PDCore

protocol LocalNotificationNotifier {
    var publisher: AnyPublisher<LocalNotification, Never> { get }
}

final class UploadFileLocalNotificationNotifier: LocalNotificationNotifier {
    private var cancellables = Set<AnyCancellable>()

    private var isApplicationInBackground = false
    private var didRequestFileNotificationInSession = false
    private var didRequestPhotosNotificationInSession = false
    private var localSettings: LocalSettings
    private let subject: PassthroughSubject<LocalNotification, Never>

    let publisher: AnyPublisher<LocalNotification, Never>

    init(
        didInterruptOnFileUploadPublisher: AnyPublisher<Void, Never>,
        didInterruptOnPhotoUploadPublisher: AnyPublisher<Void, Never>,
        didFindIssueOnFileUploadPublisher: AnyPublisher<Void, Never>,
        didChangeAppRunningStatePublisher: AnyPublisher<ApplicationRunningState, Never>,
        localSettings: LocalSettings,
        notificationsResource: LocalNotificationsResource
    ) {
        self.localSettings = localSettings
        subject = PassthroughSubject<LocalNotification, Never>()
        publisher = subject.eraseToAnyPublisher()

        didChangeAppRunningStatePublisher
            .sink { [weak self] in self?.onAppStateDidChange(to: $0) }
            .store(in: &cancellables)

        didInterruptOnFileUploadPublisher
            .flatMap { notificationsResource.isAuthorized() }
            .filter { $0 }
            .sink { [weak self] _ in self?.showInterruptedFileNotification() }
            .store(in: &cancellables)

        didInterruptOnPhotoUploadPublisher
            .flatMap { notificationsResource.isAuthorized() }
            .filter { $0 }
            .sink { [weak self] _ in self?.showInterruptedPhotoNotification() }
            .store(in: &cancellables)

        didFindIssueOnFileUploadPublisher
            .flatMap { notificationsResource.isAuthorized() }
            .filter { $0 }
            .sink { [weak self] _ in self?.showFailedNotification() }
            .store(in: &cancellables)
    }

    private var canShowFileNotification: Bool {
        !didRequestFileNotificationInSession && isApplicationInBackground
    }

    // We only show the photo notification once, when the user is in the background, and if the any of the file notifications have been shown we do not show the photo notification
    private var canShowPhotosNotification: Bool {
        isApplicationInBackground && !didRequestFileNotificationInSession && localSettings.didShowPhotosNotification != true
    }

    private func onAppStateDidChange(to state: ApplicationRunningState) {
        isApplicationInBackground = state == .background

        guard state == .foreground else { return }
        didRequestFileNotificationInSession = false
        didRequestPhotosNotificationInSession = false
    }

    private func showInterruptedFileNotification() {
        displayFileNotification(.interruptedFileUpload)
    }

    private func showFailedNotification() {
        displayFileNotification(.failedUpload)
    }

    private func showInterruptedPhotoNotification() {
        // We only show the photo notification once, when the user is in the background
        guard canShowPhotosNotification else { return }

        // We request the notification to be posted
        subject.send(.interruptedPhotoUpload)

        // We mark that we requested the notification in THIS session
        didRequestPhotosNotificationInSession = true
        // We save the state of displayed notification
        localSettings.didShowPhotosNotification = true
    }

    private func displayFileNotification(_ localNotification: LocalNotification) {
        guard canShowFileNotification else { return }

        subject.send(localNotification)
        didRequestFileNotificationInSession = true

        // If we requested the photo notification in this session, we reset the state of the photos notification, because we override the notification displayed to the user.
        // We do not show both notifications at the same time. So we need to reset the "shown" state of the photos notification.
        if didRequestPhotosNotificationInSession {
            localSettings.didShowPhotosNotification = false
        }
    }
}
