//
//  UploadFileLocalNotificationNotifier.swift
//  ProtonDrive
//
//  Created by Aaron HR on 1/30/23.
//  Copyright © 2023 ProtonMail. All rights reserved.
//

import UserNotifications
import Foundation
import Combine

protocol LocalNotificationNotifier {
    var publisher: AnyPublisher<LocalNotification, Never> { get }
}

final class UploadFileLocalNotificationNotifier: LocalNotificationNotifier {
    private var cancellables = Set<AnyCancellable>()

    private var isApplicationInBackground = false
    private var userDidAuthorizeNotification = false
    private var didShowNotificationInSession = false
    private let subject: PassthroughSubject<LocalNotification, Never>

    let publisher: AnyPublisher<LocalNotification, Never>

    init(
        didStartFileUploadPublisher: AnyPublisher<Void, Never>,
        didFindIssueOnFileUploadPublisher: AnyPublisher<Void, Never>,
        didChangeAppRunningStatePublisher: AnyPublisher<ApplicationRunningState, Never>,
        notificationsAuthorizer: @escaping (UNAuthorizationOptions) async throws -> Bool
    ) {
        subject = PassthroughSubject<LocalNotification, Never>()
        publisher = subject.eraseToAnyPublisher()

        didStartFileUploadPublisher
        //
        // hotfix: disable local notifications permission request until [DRVIOS-1723][DRVIOS-1724] is merged
        // discard this hunk if it causes merge conflicts with develop
        //
        // instead of this line:
        //  .asyncMap { _ in return try await notificationsAuthorizer([.alert]) }
        // we'll have this:
            .asyncMap { _ in return false }
        // end of hotfix
        //
            .replaceError(with: false)
            .sink { [weak self] in self?.updateUserAuthorizationStatus($0) }
            .store(in: &cancellables)

        didChangeAppRunningStatePublisher
            .sink { [weak self] in self?.onAppStateDidChange(to: $0) }
            .store(in: &cancellables)

        didFindIssueOnFileUploadPublisher
            .sink { [weak self] _ in self?.showNotification() }
            .store(in: &cancellables)
    }

    private var canShowNotification: Bool {
        !didShowNotificationInSession && userDidAuthorizeNotification && isApplicationInBackground
    }

    private func updateUserAuthorizationStatus(_ isAuthorized: Bool) {
        userDidAuthorizeNotification = isAuthorized
    }

    private func onAppStateDidChange(to state: ApplicationRunningState) {
        isApplicationInBackground = state == .background

        guard state == .foreground else { return }
        didShowNotificationInSession = false
    }

    private func showNotification() {
        guard canShowNotification else { return }

        subject.send(.incompleteUpload)
        didShowNotificationInSession = true
    }
}
