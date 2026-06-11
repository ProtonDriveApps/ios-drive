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
import PDCore
import PDCoreIOS
import PDUIComponents
import PDLocalization

struct IncomingFilesDestinationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var externalRoot: RootViewModel // this is root of the parent hierarchy
    @State var createFolderIn: Folder?
    let nodeID: NodeIdentifier
    let coordinator: FinderCoordinator
    @State var internalRoot = RootViewModel() // this is root inside the modal hierarchy

    init(nodeID: NodeIdentifier, coordinator: FinderCoordinator) {
        self.nodeID = nodeID
        self.coordinator = coordinator
    }

    var body: some View {
        RootDeeplinkableView(navigationTracker: coordinator) {
            coordinator.start(.incomingFiles(rootNodeID: nodeID))
        }
        .overlay(
            ActionBar(onSelection: actionBarAction,
                      leadingItems: [.cancel],
                      trailingItems: [.createFolder])
        )
        .presentView(item: $createFolderIn, style: .sheet) {
            coordinator.go(to: .createFolder(parent: $0)).environmentObject(internalRoot)
        }
        .onReceive(internalRoot.closeCurrentSheet) { _ in
            createFolderIn = nil
        }
        .onReceive(externalRoot.closeCurrentSheet) { _ in
            dismissPicker()
        }
    }

    func actionBarAction(_ selected: ActionBarButtonViewModel?) {
        switch selected {
        case .createFolder:

            if let currentFolder = currentFolder, currentFolder.isDeviceRoot {
                let errorHandler = UserMessageHandler()
                errorHandler.handleError(PlainMessageError(Localization.computers_error_new_folder))
            } else {
                createFolderIn = currentFolder
            }
        case .cancel:
            dismissPicker()

        default: break
        }
    }

    var currentFolder: Folder? {
        coordinator.topmostDescendant?.model?.folder ?? coordinator.model?.folder
    }

    private func dismissPicker() {
        if let rootViewController = coordinator.rootViewController {
            rootViewController.dismiss(animated: true)
        } else {
            dismiss()
        }
    }
}
