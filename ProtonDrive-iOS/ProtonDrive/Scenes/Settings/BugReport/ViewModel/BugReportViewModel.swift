// Copyright (c) 2025 Proton AG
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
import PDClient
import UIKit
import PDCoreIOS
import PDLocalization

final class ReportBugViewModel: ObservableObject {

    @Published var topicField: TopicField = TopicField()
    @Published var selectedTopic: ReportTopic = .other

    @Published var messageField = MessageField()
    @Published var messageText: String = "" {
        didSet {
            updateSendButtonState()
        }
    }
    let usernameField = UsernameField()
    @Published var username: String
    let emailField = EmailField()
    @Published var email: String {
        didSet { updateSendButtonState() }
    }

    @Published var attachmentsField = AttachmentsField()
    @Published var areLogsAttached: Bool = false

    @Published var uploadStatusText: String = ""

    @Published var sendButton = SendButton()
    @Published var isSendButtonActive: Bool = false

    @Published var selectedLogs: [URL] = []
    @Published var selectedMedia: [URL] = []

    // MARK: - Dependencies
    private let service: BugReportServiceProtocol
    private let sessionVault: SessionVault?
    private let messageHandler: UserMessageHandlerProtocol
    private let logsDirectory: URL
    private let reportedSubject = PassthroughSubject<Void, Never>()
    var reportedPublisher: AnyPublisher<Void, Never> {
        reportedSubject.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }

    // MARK: - Init
    init(service: BugReportServiceProtocol, sessionVault: SessionVault?, messageHandler: UserMessageHandlerProtocol = UserMessageHandler()) {
        self.service = service
        self.sessionVault = sessionVault
        self.messageHandler = messageHandler
        self.logsDirectory = LogExporter().prepareArchivedLogsDirectory()
        let emailValue = sessionVault?.currentAddress()?.email ?? ""
        self.email = emailValue
        self.username = sessionVault?.currentAddress()?.displayName ?? emailValue
    }

    @MainActor
    func sendReportAsync() async {
        guard isSendButtonActive else { return }
        do {
            let report = makeReport()
            try await service.reportBug(report)
            reportedSubject.send()
        } catch {
            Log.error(error: error, domain: .logs)
            messageHandler.handleError(PlainMessageError(Localization.report_bug_submission_failure + " \(error.localizedDescription)"))
        }
    }

    func presentSuccessBanner() {
        messageHandler.handleSuccess(Localization.report_bug_submission_success)
    }

    func didTapLogs() {
        if selectedLogs.isEmpty {
            do {
                selectedLogs = try FileManager.default
                    .contentsOfDirectory(at: logsDirectory, includingPropertiesForKeys: [.creationDateKey])
                    .filter { !$0.isHiddenFile }
                    .sorted { $0.creationDate > $1.creationDate }
                areLogsAttached = true
            } catch {
                Log.error(error: error, domain: .logs)
            }
        } else {
            selectedLogs.removeAll()
            areLogsAttached = false
        }

        updateSendButtonState()
    }

    func updateMedia(_ media: [URL]) {
        selectedMedia.append(contentsOf: media)
        updateSendButtonState()
    }

    func removeLog(_ log: URL) {
        selectedLogs.removeAll { $0 == log }
        updateSendButtonState()
    }

    func removeMedia(_ media: URL) {
        selectedMedia.removeAll { $0 == media }
        try? FileManager.default.removeItem(at: media)
        updateSendButtonState()
    }

    private func updateSendButtonState() {
        let messageSize = messageText.trimTrailingSpaces().count
        let attachmentsCount = (selectedLogs + selectedMedia).count
        let logsSize = Double(selectedLogs.compactMap(\.fileSize).reduce(0, +))
        let mediaSize = Double(selectedMedia.compactMap(\.fileSize).reduce(0, +))
        let uploadsSize = ((logsSize + mediaSize) / (1024 * 1024))
        let validEmail = email.isValidEmail()

        let isValid = (messageSize >= 10) && (attachmentsCount <= 10) && (uploadsSize <= 50) && validEmail

        uploadStatusText = attachmentsField.uploadStatusFormat(uploadsSize, attachmentsCount)
        isSendButtonActive = isValid
    }

    func makeReport() -> BugReport {
        BugReport(
            os: UIDevice.current.systemName,
            osVersion: UIDevice.current.systemVersion,
            client: Bundle.main.bundleIdentifier ?? "Unknown",
            clientType: 4,
            clientVersion: Bundle.main.majorVersion,
            title: "iOS Drive: \(selectedTopic.rawValue)",
            description: messageText.trimTrailingSpaces(),
            username: username,
            email: email,
            files: selectedLogs + selectedMedia
        )
    }

    // MARK: - Cleanup

    deinit {
        try? FileManager.default.removeItem(at: PDFileManager.bugReportAttachmentsDirectory)
    }

    // MARK: - Field Models

    struct TopicField {
        let title = Localization.report_bug_topic_field_title
        let topics = ReportTopic.allCases.sorted(by: { $0.name < $1.name })
    }

    struct MessageField {
        let title = Localization.report_bug_message_field_title
        let placeholder = Localization.report_bug_message_field_placeholder
        let warning = Localization.report_bug_message_field_warning
    }

    struct UsernameField {
        let title = Localization.report_bug_account_field_title
        let placeholder = Localization.report_bug_account_field_placeholder
    }

    struct EmailField {
        let title = Localization.report_bug_email_field_title
        let placeholder = Localization.report_bug_email_field_placeholder
        let warning = Localization.report_bug_email_field_warning
    }

    struct AttachmentsField {
        let title = Localization.report_bug_attachment_field_title
        let addFromFiles = Localization.report_bug_attachment_field_add_from_files
        let addFromGallery = Localization.report_bug_attachment_field_add_from_gallery
        let logsCheckBox = Localization.report_bug_attachment_field_logs_checkbox
        let uploadStatusFormat = Localization.report_bug_attachment_field_upload_status_format
    }

    struct SendButton {
        let title = Localization.report_bug_send_button_title
    }
}
