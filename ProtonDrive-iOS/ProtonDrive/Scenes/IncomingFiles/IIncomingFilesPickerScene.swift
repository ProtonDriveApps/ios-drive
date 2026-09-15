// Copyright (c) 2026 Proton AG
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
import PDCore
import PDCoreIOS
import PDLocalization
import PDSDKCore
import PDUIComponents

@MainActor
final class IIncomingFilesPickerScene: FinderPresenting {
    let currentTab: TabBarItem? = nil
    let hasModalActionBar: Bool = true
    let isUploadDisclaimerVisible: Bool = false
    let modalLeadingActionItems: [ActionBarButtonViewModel] = [.cancel]
    let modalTrailingActionItems: [ActionBarButtonViewModel] = [.createFolder]
    let shouldReportPerformance: Bool = false
    let supportsLayoutSwitch: Bool = false
    let supportsMultipleSelection: Bool = false
    let supportsSortingSwitch: Bool = false

    private let currentFolder: NodeDTO
    private let onSaveHere: (NodeDTO) -> Void
    private let viewModelFactory: FinderViewModelFactory

    init(
        folder: NodeDTO,
        onSaveHere: @escaping (NodeDTO) -> Void,
        viewModelFactory: FinderViewModelFactory
    ) {
        self.currentFolder = folder
        self.onSaveHere = onSaveHere
        self.viewModelFactory = viewModelFactory
    }
}

// MARK: - Navigation bar present
extension IIncomingFilesPickerScene {
    var navigationTitle: String {
        currentFolder.isRoot ? Localization.menu_text_my_files : currentFolder.name
    }

    var trailingNavBarItems: [NavigationBarButton] {
        [.apply(title: Localization.share_action_save_here, disabled: false)]
    }

    var leadingNavBarItems: [NavigationBarButton] {
        [.apply(title: "", disabled: true)]
    }
}

// MARK: - Cell
extension IIncomingFilesPickerScene {
    func makeCellViewModel(for node: NodeDTO) -> FFinderCellViewModel {
        viewModelFactory.makeCellViewModel(
            parameters: .init(
                actionHandler: nil,
                isSharedWithMeRoot: currentFolder.isSharedWithMeRoot,
                node: node,
                selectionModel: nil,
                shouldDisable: node.isFile,
                supportSelection: false
            )
        )
    }

    func applyAction() async throws {
        onSaveHere(currentFolder)
    }
}

// MARK: - Not relative
extension IIncomingFilesPickerScene {
    func bottomActionItems(selected: [NodeDTO]) -> [ActionBarButtonViewModel] { [] }

    func startRecordingPerformance(id: AnyVolumeIdentifier) { }
}
