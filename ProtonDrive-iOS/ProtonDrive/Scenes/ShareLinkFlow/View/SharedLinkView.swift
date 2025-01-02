// Copyright (c) 2023 Proton AG
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

struct SharedLinkView<EditingView: View>: View {
    @ObservedObject private var vm: SharedLinkViewModel
    @EnvironmentObject private var root: RootViewModel

    private var editingView: EditingView

    init(
        vm: SharedLinkViewModel,
        editingView: EditingView
    ) {
        self.vm = vm
        self.editingView = editingView
    }

    var body: some View {
        if #available(iOS 17.0, *) {
            content
                .scrollDismissesKeyboard(.interactively)
        } else {
            content
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                firstSection(vm.state.detailSection)
                    .separated()

                secondSection()
                    .separated()

                thirdSection(vm.state.actionsSection)
                    .actionSheet(isPresented: $vm.attemptDeleteLink) {
                        ActionSheet(
                            title: Text(vm.stopSharingAlertTitle),
                            message: Text(vm.stopSharingAlertMessage),
                            buttons: [
                                .cancel(),
                                .destructive(
                                    Text(vm.stopSharingButton),
                                    action: vm.deleteLink
                                ),
                            ]
                        )
                    }
            }
        }
        .edgesIgnoringSafeArea(.all)
        .onReceive(vm.$isScreenClosed) { output in
            guard output else { return }
            root.closeCurrentSheet.send()
        }
    }

    private func firstSection(_ section: SharedLinkSection) -> some View {
        ListSection(header: section.title) {
            VStack(alignment: .leading, spacing: 24) {
                LongPressCopyCell(
                    text: section.link,
                    image: IconProvider.link,
                    onLongPress: { vm.perform(.copyLink) }
                )

                FormattedSharedLink(
                    text: section.formattedText.regular,
                    boldText: section.formattedText.bold
                )
            }
        }
    }

    func secondSection() -> some View {
        editingView
    }

    func thirdSection(_ section: LinkActionsSection) -> some View {
        ListSection {
            ForEach(section.actions) { action in
                LabelCell(title: action.text, icon: action.icon, action: { vm.perform(action) })
                    .accessibility(identifier: action.accessibilityIdentifier)
            }
        }
        .sheet(isPresented: $vm.shareLink) {
            ShareSheet(activityItems: [vm.formattedLink])
        }
    }
}

private struct FormattedSharedLink: View {
    let text: String
    let boldText: String

    var body: some View {
        Group {
            Text("\(text) ")
                .fontWeight(.regular) +
            Text(boldText)
                .fontWeight(.semibold) +
            Text(".")
                .fontWeight(.regular)
        }
        .padding(.horizontal)
    }
}

extension LinkActionsSection.ActionType: Identifiable {
    var id: Self { self }

    var text: String {
        switch self {
        case .copyLink:
            return Localization.share_action_copy_link
        case .copyPassword:
            return Localization.share_action_copy_password
        case .share:
            return Localization.share_action_share
        case .delete:
            return Localization.share_action_stop_sharing
        }
    }

    var icon: Image {
        switch self {
        case .copyLink:
            return IconProvider.link
        case .copyPassword:
            return IconProvider.keySkeleton
        case .share:
            return IconProvider.arrowUpFromSquare
        case .delete:
            return IconProvider.trash
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .copyLink:
            return "ShareSecureLinkView.Button.CopyLink"
        case .copyPassword:
            return "ShareSecureLinkView.Button.CopyPassword"
        case .share:
            return "ShareSecureLinkView.Button.Share"
        case .delete:
            return "ShareSecureLinkView.Button.Delete"
        }
    }
}
