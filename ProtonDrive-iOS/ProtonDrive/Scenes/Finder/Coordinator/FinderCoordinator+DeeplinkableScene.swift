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

import Foundation
import PDUIComponents
import PDCore

extension FinderCoordinator: DeeplinkableScene {
    private static let ParentsChainKey = "ParentsChain"
    private static let SharedKey = NodeIdentifier("Shared", "Shared", "")
    
    struct RestorationInfo {
        var parents: [NodeIdentifier]
    }
    
    var currentIdentifier: NodeIdentifier? {
        switch self.model {
        case is SharedModel: return Self.SharedKey
        default: return self.model?.folder?.identifier
        }
    }
    
    func buildStateRestorationActivity() -> NSUserActivity {
        let activity = self.makeActivity()
        let parentsChainRaw = self.fullCoordinatorsChain.compactMap(\.currentIdentifier).map(\.rawValue)
        activity.userInfo?[Self.ParentsChainKey] = parentsChainRaw
        return activity
    }
    
    func buildFileHierarchyActivity(node: Node) -> NSUserActivity {
        let activity = self.makeActivity()
        let parentsChainRaw = node.parentsChain().map(\.identifier.rawValue)
        activity.userInfo?[Self.ParentsChainKey] = parentsChainRaw
        return activity
    }
    
    func deeplink(from deeplink: Deeplink?, tower: Tower?) {
        // A delay is required, especially when the app returns from the background
        // When coming back to the foreground, FinderView refreshes due to data synchronization
        // Any UI changes triggered before that refresh may be reset
        // For example, a presented modal could be dismissed automatically after about one second
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let deeplink = deeplink?.next(after: self.currentIdentifier) { // folder, shared, activity, move
                self.drilldownTo.wrappedValue = deeplink.nodeID
            } else if let modal = deeplink?.finalModal(), let file = tower?.uiSlot?.subscribeToNode(modal) as? File { // file
                self.presentModal.wrappedValue = .file(file: file)
                deeplink?.invalidate()
            } else if let action = deeplink?.finalAction() {
                    switch action {
                    case .scanDocument:
                        self.presentModal.wrappedValue = .scanDocument
                    }
                deeplink?.invalidate()
            } else { // end of sequence
                deeplink?.invalidate()
            }
        }
    }
    
    static func restore(from userInfo: [AnyHashable: Any]?) -> RestorationInfo? {
        guard let parentsRaw = userInfo?[Self.ParentsChainKey] as? [NodeIdentifier.RawValue],
              case let parents = parentsRaw.compactMap(NodeIdentifier.init) else
        {
            return nil
        }
        
        return RestorationInfo(parents: parents)
    }
}

extension Deeplink {
    func inject(restoration: FinderCoordinator.RestorationInfo) {
        self.inject(restoration.parents)
    }
}
