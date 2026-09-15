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
import PDUIComponents
import PDLocalization
import PDCore
import PDCoreIOS
import PDSDKCore

@MainActor
final class MoveFinderScene: FinderPresenting {
    @Published private var isUpdating = false
    let currentTab: TabBarItem? = nil
    let hasModalActionBar: Bool = true
    let isUploadDisclaimerVisible: Bool = false
    let modalLeadingActionItems: [ActionBarButtonViewModel] = [.cancel]
    let modalTrailingActionItems: [ActionBarButtonViewModel] = [.createFolder]
    let selectedNodes: [NodeDTO]
    let shouldReportPerformance: Bool = false
    let supportsLayoutSwitch: Bool = false
    let supportsMultipleSelection: Bool = false
    let supportsSortingSwitch: Bool = false
    private let currentFolder: NodeDTO
    private let viewModelFactory: FinderViewModelFactory
    private let tower: Tower

    init(folder: NodeDTO, selectedNodes: [NodeDTO], viewModelFactory: FinderViewModelFactory, tower: Tower) {
        self.currentFolder = folder
        self.selectedNodes = selectedNodes
        self.viewModelFactory = viewModelFactory
        self.tower = tower
    }
}

// MARK: - Navigation bar present
extension MoveFinderScene {
    var navigationTitle: String { currentFolder.isRoot ? Localization.menu_text_my_files : currentFolder.name }

    var trailingNavBarItems: [NavigationBarButton] {
        [.apply(title: Localization.move_action_move_here, disabled: isMoveHereDisabled)]
    }
    var leadingNavBarItems: [NavigationBarButton] { [.apply(title: "", disabled: true)] }

    // TODO: finder-refactor Maybe don't add new property to NodeDTO, it's too big
    //    private var isMoveToDeviceRoot: Bool { currentFolder.isde}
    private var isMoveHereDisabled: Bool { isMoveToItSelf || isUpdating }
    private var isMoveToItSelf: Bool { selectedNodes.first?.parentID == currentFolder.id }
}

extension MoveFinderScene {
    func makeCellViewModel(for node: NodeDTO) -> FFinderCellViewModel {
        let shouldDisabled = node.isFile || selectedNodes.map(\.id).contains(node.id)
        return viewModelFactory.makeCellViewModel(
            parameters: .init(
                actionHandler: nil,
                isSharedWithMeRoot: currentFolder.isSharedWithMeRoot,
                node: node,
                selectionModel: nil,
                shouldDisable: shouldDisabled,
                supportSelection: false
            )
        )
    }

    func applyAction() async throws {
        isUpdating = true
        defer { isUpdating = false }
        let context = tower.storage.synchronousContextPool.acquire()
        defer { tower.storage.synchronousContextPool.relinquish(context) }

        let (newParent, nodes) = await context.perform { [context] in
            let folder: CoreDataFolder? = try? context.typedObject(with: self.currentFolder.objectID)
            let nodes: [CoreDataNode] = self.selectedNodes.compactMap { try? context.typedObject(with: $0.objectID) }
            return (folder, nodes)
        }
        guard let newParent else {
            throw CoreDataFolder.InvalidState(message: "Can't find target folder")
        }

        guard nodes.count == selectedNodes.count else {
            throw CoreDataFile.InvalidState(message: "Can't find selected nodes")
        }

        let infoReader = NodeCryptoMaterialReader(moc: context, signersKitFactory: tower.sessionVault)
        let linksFactory = MultipleMovingNodeLinkFactory(infoReader: infoReader, moc: context)
        let parentIDFetcher = NodeParentIDFetcher(storage: tower.storage)
        let mover = MultipleNodeMover(
            cloudMultipleNodeMover: tower.client.moveMultiple(volumeID:parameters:),
            moc: context,
            infoReader: infoReader,
            linksFactory: linksFactory,
            parentIDFetcher: parentIDFetcher
        )

        try await mover.move(nodes, to: newParent)
    }
}

// MARK: - Not relative
extension MoveFinderScene {
    func bottomActionItems(selected: [NodeDTO]) -> [ActionBarButtonViewModel] { [] }

    func startRecordingPerformance(id: AnyVolumeIdentifier) { }
}
