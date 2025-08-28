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

import SwiftUI
import PDUIComponents
import ProtonCoreUIFoundations
import PDLocalization

struct InvitationView: View {
    @EnvironmentObject var hostingProvider: ViewControllerProvider
    @ObservedObject var viewModel: InvitationViewModel
    @FocusState private var textFieldFocus: Bool
    @State private var textEditorHeight: CGFloat?
    private let searchTextFieldID = "contactSearchTextField"
    
    init(viewModel: InvitationViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        if viewModel.isReady {
            ZStack {
                dummyTextView
                VStack(spacing: 0) {
                    configView
                    if viewModel.includingMessage && viewModel.queryResult.isEmpty {
                        textCounterView
                    }
                }
            }
            .onPreferenceChange(ViewHeightKey.self) { textEditorHeight = $0 }
            .onChange(of: textFieldFocus, perform: { newValue in
                if !newValue {
                    submitCandidateQuery()
                }
            })
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    dismissButton
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    inviteButton()
                }
            }
        } else {
            SpinnerTextView(text: "")
        }
    }
    
    private var configView: some View {
        ScrollViewReader(content: { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    candidateRow
                    if viewModel.queryResult.isEmpty {
                        permissionRow
                        Rectangle()
                            .foregroundColor(ColorProvider.BackgroundSecondary)
                            .frame(height: 8)
                            .ignoresSafeArea(edges: .horizontal)
                        inviteMessageSectionHeader
                        if viewModel.includingMessage {
                            inviteMessageTextView
                                .padding(.top, 5)
                        }
                    } else {
                        queryList
                    }
                }
            }
            .onChange(of: viewModel.candidates.count, perform: { _ in
                proxy.scrollTo(searchTextFieldID)
            })
        })
    }
}

// MARK: - Contact search
extension InvitationView {
    private var candidateRow: some View {
        HStack(alignment: .top, spacing: 8) {
            AvatarView(
                config: .init(
                    avatarSize: .init(width: 48, height: 48),
                    content: .right(IconProvider.userPlus),
                    backgroundColor: .clear,
                    foregroundColor: ColorProvider.IconWeak,
                    iconSize: .init(width: 24, height: 24)
                )
            )

            VStack(alignment: .leading, spacing: 12) {
                candidateList
                contactSearchTextField
                    .id(searchTextFieldID)
            }
            .padding(.top, 12)
        }
        .frame(minHeight: 65)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            textFieldFocus = true
        }
    }
    
    private var contactSearchTextField: some View {
        EnhancedTextField(
            placeholder: viewModel.queryPlaceholder,
            text: $viewModel.queryText
        ) { onEmpty in
            guard onEmpty else { return }
            if let id = viewModel.selectedCandidateID {
                viewModel.removeCandidate(id: id)
                viewModel.selectedCandidateID = nil
            } else {
                viewModel.selectedCandidateID = viewModel.candidates.last?.id
            }
        } onSubmit: {
            submitCandidateQuery()
        }
        .focused($textFieldFocus)
        .frame(height: 25)
        .accessibilityIdentifier("ContactSearchTextField.EnhancedTextField")
    }
    
    private var queryList: some View {
        ForEach(viewModel.queryResult) { result in
            VStack(alignment: .center, spacing: 0) {
                Spacer()
                Text(result.attributedName)
                    .font(.system(size: 17))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 16)
                Text(result.attributedInfo)
                    .font(.system(size: 15))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 16)
                Spacer()
            }
            .overlay(Divider(), alignment: .bottom)
            .frame(height: 65)
            .contentShape(Rectangle()) // To enable tap gesture
            .onTapGesture {
                viewModel.add(candidate: result)
                viewModel.queryText = ""
            }
        }
    }
    
    private var candidateList: some View {
        ForEach(viewModel.candidates) { candidate in
            let isSelected: Binding<Bool> = .init { viewModel.selectedCandidateID == candidate.id } set: { _ in }

            InvitationCandidateCell(candidate: candidate, isSelected: isSelected)
            .contentShape(Rectangle()) // To enable tap gesture
            .onTapGesture {
                if viewModel.selectedCandidateID == candidate.id && candidate.isGroup && !candidate.isDuplicated {
                    UIApplication.shared.endEditing()
                    viewModel.presentActionSheet(for: candidate)
                } else {
                    viewModel.selectedCandidateID = candidate.id
                    textFieldFocus = true
                }
                
                if candidate.isDuplicated {
                    viewModel.presentDuplicatedInvitationError()
                }
            }
        }
    }

    private func submitCandidateQuery() {
        viewModel.addCandidate(by: viewModel.queryText)
        viewModel.queryText = ""
    }
}

// MARK: - Permission
extension InvitationView {
    private var permissionRow: some View {
        HStack(spacing: 8) {
            AvatarView(
                config: .init(
                    avatarSize: .init(width: 48, height: 48),
                    content: .right(IconProvider.pencil),
                    backgroundColor: .clear,
                    foregroundColor: ColorProvider.IconWeak,
                    iconSize: .init(width: 24, height: 24)
                )
            )
            
            Text(viewModel.permissionTitle)
                .modifier(TextModifier(fontSize: 17, textColor: ColorProvider.TextNorm))
                .accessibilityIdentifier("InvitationView.permission.\(viewModel.permissionAccessibilityIdentifier)")
            
            AvatarView(
                config: .init(
                    avatarSize: .init(width: 16, height: 16),
                    content: .right(IconProvider.chevronDownFilled),
                    backgroundColor: .clear,
                    iconSize: .init(width: 16, height: 16)
                )
            )
            .padding(.trailing, 16)
        }
        .frame(minHeight: 65)
        .contentShape(Rectangle()) // To enable tap gesture
        .onTapGesture {
            UIApplication.shared.endEditing()
            presentPermissionEditSheet()
        }
    }
    
    private func presentPermissionEditSheet() {
        guard let nav = hostingProvider.viewController?.navigationController else { return }
        let isEditor = viewModel.permission.contains([.read, .write])
        
        var sheet: PMActionSheet!
        let viewerItem = PMActionSheetItem(
            style: .default(IconProvider.eye, Localization.sharing_member_role_viewer),
            markType: isEditor ? .none : .checkMark
        ) { item in
            viewModel.permission = [.read]
            sheet.dismiss(animated: true)
            sheet = nil
        }
        
        let editorItem = PMActionSheetItem(
            style: .default(IconProvider.pencil, Localization.sharing_member_role_editor),
            markType: isEditor ? .checkMark : .none
        ) { item in
            viewModel.permission = [.read, .write]
            sheet.dismiss(animated: true)
            sheet = nil
        }

        let group = PMActionSheetItemGroup(items: [viewerItem, editorItem], style: .singleSelection)
        sheet = PMActionSheet(headerView: nil, itemGroups: [group])
        sheet.presentAt(nav, hasTopConstant: false, animated: true)
    }
}

// MARK: - Invite message
extension InvitationView {
    private var inviteMessageSectionHeader: some View {
        VStack(spacing: 0) {
            sectionHeader(
                title: viewModel.inviteMessageTitle,
                button: {
                    AvatarView(
                        config: .init(
                            avatarSize: .init(width: 16, height: 16),
                            content: .right(IconProvider.cogWheel),
                            backgroundColor: .clear,
                            foregroundColor: ColorProvider.IconWeak,
                            iconSize: .init(width: 16, height: 16)
                        )
                    )
                }
            )
        }
        .padding(.horizontal, 16)
        .contentShape(Rectangle()) // To enable tap gesture
        .onTapGesture {
            UIApplication.shared.endEditing()
            viewModel.presentMessageSetting()
        }
    }
    
    private var inviteMessageTextView: some View {
        ZStack(alignment: .leading) {
            TextEditor(text: $viewModel.inviteMessage)
                .font(.system(size: 17))
                .foregroundColor(ColorProvider.TextNorm)
                .padding(.trailing, 8)
                .padding(.leading, -4) // To align header
                .frame(minHeight: 24)
                .frame(height: textEditorHeight)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("InvitationView.inviteMessageTextView")
            Text(Localization.sharing_invitation_message_placeholder)
                .font(.system(size: 17))
                .frame(alignment: .leading)
                .foregroundColor(ColorProvider.TextHint)
                .opacity(viewModel.inviteMessage.isEmpty ? 1 : 0)
                .allowsHitTesting(false)
        }
        .padding(.horizontal, 16)
        .opacity(viewModel.includingMessage ? 1 : 0)
    }
    
    private var textCounterView: some View {
        HStack {
            Spacer()
            Text("\(viewModel.inviteMessageCount)")
                .foregroundColor(viewModel.inviteMessage.count > viewModel.maximumMessageCount ? ColorProvider.NotificationError : ColorProvider.TextWeak)
        }
        .padding(.trailing, 18)
    }
    
    // To maintain correct height when TextEditor is removed from screen
    // If TextEditor is added to screen after removing
    // It's initialized height is incorrect
    private var dummyTextView: some View {
        ScrollView {
            VStack(spacing: 0) {
                TextEditor(text: $viewModel.inviteMessage)
                    .font(.system(size: 17))
                    .foregroundColor(.black)
                    .padding(.trailing, 8)
                    .padding(.leading, -4) // To align header
                    .frame(minHeight: 24)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(0)
                    .allowsHitTesting(false)
                    .background(GeometryReader {
                        Color.clear.preference(
                            key: ViewHeightKey.self,
                            value: $0.frame(in: .local).size.height
                        )
                    })
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Confirm view
extension InvitationView {
    @ViewBuilder
    private func inviteButton() -> some View {
        Group {
            if viewModel.isInviting {
                AnyView(ProtonSpinner(size: .medium))
            } else {
                Button(action: {
                    UIApplication.shared.endEditing()
                    viewModel.clickInviteButton()
                }, label: {
                    AvatarView(
                        config: .init(
                            avatarSize: .init(width: 40, height: 40),
                            content: .right(IconProvider.paperPlaneHorizontal),
                            backgroundColor: .clear,
                            foregroundColor: viewModel.isInviteButtonEnabled ? ColorProvider.IconAccent : ColorProvider.IconDisabled,
                            iconSize: .init(width: 24, height: 24)
                        )
                    )
                })
                .disabled(!viewModel.isInviteButtonEnabled)
                .accessibilityIdentifier("InvitationView.InviteButton")
            }
        }
    }

    private var dismissButton: some View {
        Button {
            hostingProvider.viewController?.navigationController?.dismiss(animated: true)
        } label: {
            Image(uiImage: IconProvider.cross)
                .tint(ColorProvider.IconNorm)
        }
        .disabled(viewModel.isInviting)
    }
}

extension InvitationView {
    @ViewBuilder
    private func sectionHeader(title: String, button: @escaping () -> some View) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text(title)
                    .modifier(TextModifier())
                
                button()
            }
            .padding(.top, 29)
            .padding(.bottom, 8)
        }
        .frame(height: 52)
    }
}

struct ViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout Value, nextValue: () -> Value) {
        value += nextValue()
    }
}
