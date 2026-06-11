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
import PDCore
import PDUIComponents
import SwiftUI
import UIKit

struct IncomingFilesCoordinator {
    func present(
        on rootViewController: UIViewController,
        with authenticatedContainer: AuthenticatedDependencyContainer
    ) {
        Log.info("Presenting incoming files save view", domain: .shareExtension)
        let myFilesRootFetcher = MyFilesRootFetcher(storage: authenticatedContainer.tower.storage)
        let rootNodeID = myFilesRootFetcher.getRoot()
        guard let rootFolder = authenticatedContainer.tower.uiSlot?.subscribeToNode(rootNodeID) as? Folder else {
            Log.error("Incoming files root folder is unavailable", domain: .shareExtension)
            return
        }
        let rootFileView = IncomingFilesReviewView(
            rootNodeID: rootNodeID,
            initialFolder: rootFolder,
            authenticatedContainer: authenticatedContainer
        )
        let rootView = RootView(vm: RootViewModel(), activeArea: { rootFileView })
        let vc = UIHostingController(rootView: rootView)
        vc.isModalInPresentation = true
        rootViewController.present(vc, animated: true)
    }
}
