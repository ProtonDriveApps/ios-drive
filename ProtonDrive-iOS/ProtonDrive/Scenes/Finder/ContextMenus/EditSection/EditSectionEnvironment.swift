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
import PDCore

final class EditSectionEnvironment {
    typealias Destination = FinderCoordinator.Destination
    private(set) var menuItem: Binding<FinderMenu?>
    var modal: Binding<(Destination)?>
    var sheet: Binding<(Destination)?>
    var acknowledgedNotEnoughStorage: Binding<Bool>

    init(menuItem: Binding<FinderMenu?>,
         modal: Binding<(Destination)?>,
         sheet: Binding<(Destination)?>,
         acknowledgedNotEnoughStorage: Binding<Bool>) {
        self.menuItem = menuItem
        self.modal = modal
        self.sheet = sheet
        self.acknowledgedNotEnoughStorage = acknowledgedNotEnoughStorage
    }

    func onDismiss() {
        menuItem.wrappedValue = nil
    }

    // MARK: - Edit
    func shareLink(of node: Node) {
        onDismiss()
        DispatchQueue.main.async {
            self.sheet.wrappedValue = .shareLink(node: node)
        }
    }

    func availableOffline(vm: EditSectionViewModel) {
        onDismiss()
        vm.markOfflineAvailable()
        acknowledgedNotEnoughStorage.wrappedValue = false
    }

    func star(vm: EditSectionViewModel) {
        onDismiss()
        vm.starNode()
    }

    func trashNode(of vm: NodeRowActionMenuViewModel, isNavigationMenu: Bool) {
        onDismiss()
        DispatchQueue.main.async {
            self.menuItem.wrappedValue = .trash(vm: vm, isNavigationMenu: isNavigationMenu)
        }
    }

    func rename(vm: EditSectionViewModel) {
        onDismiss()
        DispatchQueue.main.async {
            self.sheet.wrappedValue = .rename(vm.node)
        }
    }

    func move(vm: EditSectionViewModel) {
        onDismiss()
        DispatchQueue.main.async {
            self.sheet.wrappedValue = .move([vm.node], parent: vm.node.parentLink)
        }
    }

    func showDetails(vm: EditSectionViewModel) {
        onDismiss()
        DispatchQueue.main.async {
            self.sheet.wrappedValue = .nodeDetails(vm.node)
        }
    }

    // MARK: - More
    func shareIn(file: File) {
        onDismiss()
        DispatchQueue.main.async {
            self.modal.wrappedValue = .file(file: file, share: true)
        }
    }

    // MARK: - Upload
    func uploadPhoto() {
        onDismiss()
        DispatchQueue.main.async {
            self.sheet.wrappedValue = .importPhoto
        }
    }

    func takePhoto() {
        onDismiss()
        DispatchQueue.main.async {
            self.modal.wrappedValue = .camera
        }
    }

    func createFolder(vm: UploadSectionViewModel) {
        onDismiss()
        DispatchQueue.main.async {
            self.sheet.wrappedValue = .createFolder(parent: vm.folder)
        }
    }

    func importFile() {
        onDismiss()
        DispatchQueue.main.async {
            self.sheet.wrappedValue = .importDocument
        }
    }
}
