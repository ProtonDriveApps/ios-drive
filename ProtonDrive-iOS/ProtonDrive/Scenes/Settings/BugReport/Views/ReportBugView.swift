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

import SwiftUI
import UIKit
import ProtonCoreUIFoundations
import PDUIComponents

struct ReportBugView: View {
    @EnvironmentObject var hostingProvider: ViewControllerProvider
    @StateObject var viewModel: ReportBugViewModel
    @State private var showDocumentPicker = false
    @State private var showImagePicker = false

    let columns = [GridItem(.flexible())]

    var body: some View {
        VStack {
            ScrollView {
                formContent
                    .padding()
            }

            sendButton
                .padding()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            dismissKeyBoard()
        }
        .onReceive(viewModel.reportedPublisher) { _ in
            hostingProvider.viewController?.navigationController?.dismiss(animated: true, completion: {
                self.viewModel.presentSuccessBanner()
            })
        }
        .sheet(isPresented: $showDocumentPicker) {
            BugDocumentPicker { selectMedia in
                viewModel.updateMedia(selectMedia)
            }
            .edgesIgnoringSafeArea(.all)
        }
        .sheet(isPresented: $showImagePicker) {
            BugImagePicker { selectMedia in
                viewModel.updateMedia(selectMedia)
            }
            .edgesIgnoringSafeArea(.all)
        }
    }

    private var formContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            topicPickerField
            usernameField
            emailField
            messageField
            attachmentsField
            Spacer()
        }
    }

    private var topicPickerField: some View {
        BugReportFormField(label: viewModel.topicField.title) {
            HStack {
                Menu {
                    ForEach(viewModel.topicField.topics, id: \.self) { topic in
                        Button {
                            viewModel.selectedTopic = topic
                        } label: {
                            Text(topic.name)
                                .tint(ColorProvider.TextNorm)
                        }
                    }
                } label: {
                    HStack {
                        Text(viewModel.selectedTopic.name)
                            .foregroundColor(ColorProvider.TextNorm)
                        Spacer()
                        IconProvider.chevronDown
                            .foregroundColor(ColorProvider.IconNorm)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.clear)
                    .cornerRadius(8)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(ColorProvider.BrandNorm, lineWidth: 1)
                )
            }
        }
    }

    private var usernameField: some View {
        BugReportFormField(label: viewModel.usernameField.title) {
            VStack(alignment: .leading, spacing: 6) {
                TextEditorWithPlaceholder(text: $viewModel.username, placeholder: viewModel.usernameField.placeholder)
                    .padding(2)
                    .frame(minHeight: 44, maxHeight: 200)
                    .autocorrectionDisabled()
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(ColorProvider.BrandNorm, lineWidth: 1)
                    )
            }
        }
    }

    private var emailField: some View {
        BugReportFormField(label: viewModel.emailField.title) {
            VStack(alignment: .leading, spacing: 6) {
                TextEditorWithPlaceholder(text: $viewModel.email, placeholder: viewModel.emailField.placeholder)
                    .padding(2)
                    .frame(minHeight: 44, maxHeight: 200)
                    .autocorrectionDisabled()
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(ColorProvider.BrandNorm, lineWidth: 1)
                    )

                Text(viewModel.emailField.warning)
                    .font(.callout)
                    .foregroundColor(ColorProvider.TextWeak)
            }
        }
    }

    private var messageField: some View {
        BugReportFormField(label: viewModel.messageField.title) {
            VStack(alignment: .leading, spacing: 6) {
                TextEditorWithPlaceholder(text: $viewModel.messageText, placeholder: viewModel.messageField.placeholder)
                    .padding(2)
                    .frame(minHeight: 66, maxHeight: 200)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(ColorProvider.BrandNorm, lineWidth: 1)
                    )

                Text(viewModel.messageField.warning)
                    .font(.callout)
                    .foregroundColor(ColorProvider.TextWeak)
            }
        }
    }

    private var attachmentsField: some View {
        BugReportFormField(label: viewModel.attachmentsField.title) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SkeletonButton(text: viewModel.attachmentsField.addFromFiles, icon: IconProvider.fileLines) {
                        showDocumentPicker.toggle()
                    }

                    Spacer()

                    SkeletonButton(text: viewModel.attachmentsField.addFromGallery, icon: IconProvider.camera) {
                        showImagePicker.toggle()
                    }
                }

                HStack(spacing: 10) {
                    SelectionButton(isSelected: !viewModel.selectedLogs.isEmpty)
                        .frame(maxWidth: 20)
                        .onTapGesture { viewModel.didTapLogs() }
                        .onAppear { viewModel.didTapLogs() }

                    Text(viewModel.attachmentsField.logsCheckBox)
                    Spacer()
                }

                Text(viewModel.uploadStatusText)
                    .font(.callout)
                    .foregroundColor(ColorProvider.TextWeak)

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(viewModel.selectedLogs, id: \.self) { log in
                        attachmentRow(for: log, remove: {
                            viewModel.removeLog(log)
                        })
                    }
                    ForEach(viewModel.selectedMedia, id: \.self) { media in
                        attachmentRow(for: media, remove: {
                            viewModel.removeMedia(media)
                        })
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func attachmentRow(for file: URL, remove: @escaping () -> Void) -> some View {
        HStack {
            HStack {
                Text(file.lastPathComponent)
                    .lineLimit(1)
                    .truncationMode(.head)

                Button(action: remove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
            .padding(4)
            .background(RoundedRectangle(cornerRadius: 8).fill(ColorProvider.BrandNorm.opacity(0.2)))

            Spacer()
        }
    }

    private var sendButton: some View {
        LoadingButton {
            dismissKeyBoard()
            await viewModel.sendReportAsync()
        } label: {
            Text(viewModel.sendButton.title)
                .font(.subheadline)
                .foregroundColor(ColorProvider.White)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(viewModel.isSendButtonActive ? ColorProvider.BrandNorm : ColorProvider.BrandNorm.opacity(0.2))
                .cornerRadius(8)
        }
        .disabled(!viewModel.isSendButtonActive)
    }

    private func dismissKeyBoard() {
        UIApplication.shared.dismissKeyboard()
    }

    @ViewBuilder
    private func validationMessageRow(text: String, isError: Bool) -> some View {
        HStack(spacing: 8) {
            if isError {
                IconProvider.exclamationCircle
            }

            Text(text)
                .font(.callout)
        }
        .foregroundColor(isError ? ColorProvider.NotificationWarning : ColorProvider.TextWeak)
    }
}

extension UIApplication {
    func dismissKeyboard() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
