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

    @Published var attachmentsField = AttachmentsField()
    @Published var areLogsAttached: Bool = false

    @Published var uploadStatusText: String = ""

    @Published var sendButton = SendButton()
    @Published var isSendButtonActive: Bool = false

    @Published var selectedLogs: [URL] = []
    @Published var selectedMedia: [URL] = []

    // MARK: - Dependencies
    private let service: BugReportServiceProtocol
    private let sessionVault: SessionVault
    private let messageHandler: UserMessageHandlerProtocol
    private let logsDirectory: URL

    // MARK: - Init
    init(service: BugReportServiceProtocol, sessionVault: SessionVault, messageHandler: UserMessageHandlerProtocol = UserMessageHandler()) {
        self.service = service
        self.sessionVault = sessionVault
        self.messageHandler = messageHandler
        self.logsDirectory = LogExporter().prepareArchivedLogsDirectory()
    }

    @MainActor
    func sendReportAsync() async {
        guard isSendButtonActive else { return }
        do {
            let report = makeReport()
            try await service.reportBug(report)
            messageHandler.handleSuccess(Localization.report_bug_submission_success)
        } catch {
            Log.error(error: error, domain: .logs)
            messageHandler.handleError(PlainMessageError(Localization.report_bug_submission_failure + " \(error.localizedDescription)"))
        }
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

        let isValid = (messageSize >= 10) && (attachmentsCount <= 10) && (uploadsSize <= 50)

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

    private var email: String {
        sessionVault.currentAddress()?.email ?? ""
    }

    private var username: String {
        sessionVault.currentAddress()?.displayName ?? email
    }

    // MARK: - Cleanup

    deinit {
        try? FileManager.default.removeItem(at: PDFileManager.bugReportAttachmentsDirectory)
    }

    // MARK: - Field Models

    struct TopicField {
        let title = Localization.report_bug_topic_field_title
        let topics = ReportTopic.allCases
    }

    struct MessageField {
        let title = Localization.report_bug_message_field_title
        let placeholder = Localization.report_bug_message_field_placeholder
        let warning = Localization.report_bug_message_field_warning
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
