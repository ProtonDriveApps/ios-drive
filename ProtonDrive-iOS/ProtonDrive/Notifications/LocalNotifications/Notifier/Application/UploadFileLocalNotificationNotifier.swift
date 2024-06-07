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

protocol LocalNotificationNotifier {
    var publisher: AnyPublisher<LocalNotification, Never> { get }
}

final class UploadFileLocalNotificationNotifier: LocalNotificationNotifier {
    private var cancellables = Set<AnyCancellable>()

    private var isApplicationInBackground = false
    private var didShowNotificationInSession = false
    private let subject: PassthroughSubject<LocalNotification, Never>

    let publisher: AnyPublisher<LocalNotification, Never>

    init(
        didInterruptOnFileUploadPublisher: AnyPublisher<Void, Never>,
        didFindIssueOnFileUploadPublisher: AnyPublisher<Void, Never>,
        didChangeAppRunningStatePublisher: AnyPublisher<ApplicationRunningState, Never>,
        notificationsResource: LocalNotificationsResource
    ) {
        subject = PassthroughSubject<LocalNotification, Never>()
        publisher = subject.eraseToAnyPublisher()

        didChangeAppRunningStatePublisher
            .sink { [weak self] in self?.onAppStateDidChange(to: $0) }
            .store(in: &cancellables)

        didInterruptOnFileUploadPublisher
            .flatMap { notificationsResource.isAuthorized() }
            .filter { $0 }
            .sink { [weak self] _ in self?.showInterruptedNotification() }
            .store(in: &cancellables)

        didFindIssueOnFileUploadPublisher
            .flatMap { notificationsResource.isAuthorized() }
            .filter { $0 }
            .sink { [weak self] _ in self?.showFailedNotification() }
            .store(in: &cancellables)
    }

    private var canShowNotification: Bool {
        !didShowNotificationInSession && isApplicationInBackground
    }

    private func onAppStateDidChange(to state: ApplicationRunningState) {
        isApplicationInBackground = state == .background

        guard state == .foreground else { return }
        didShowNotificationInSession = false
    }

    private func showInterruptedNotification() {
        guard canShowNotification else { return }

        subject.send(.interruptedUpload)
        didShowNotificationInSession = true
    }

    private func showFailedNotification() {
        guard canShowNotification else { return }

        subject.send(.failedUpload)
        didShowNotificationInSession = true
    }
}
