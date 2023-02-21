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
import SwiftUI
import PDCore
import PDUIComponents

class FileCoordinator: SwiftUICoordinator {
    typealias Context = (file: File, share: Bool)
    
    private let tower: Tower
    private let parentCoordinator: FinderCoordinator?
    private var file: File?
    
    init(tower: Tower, parent: FinderCoordinator?) {
        self.tower = tower
        self.parentCoordinator = parent
    }

    func start(_ context: Context) -> FileView {
        self.file = context.file
        let model = FileModel(tower: tower, revision: context.file.activeRevision)
        return FileView(coordinator: self, model: model, share: context.share)
    }

    func go(to destination: Never) -> Never { }
}

extension FileCoordinator: DeeplinkableScene {
    private static let FilePresenterKey = "FilePresenter"
    
    struct RestorationInfo {
        var parents: FinderCoordinator.RestorationInfo
        var file: NodeIdentifier
    }
    
    func buildStateRestorationActivity() -> NSUserActivity {
        let activity = self.makeActivity()
        if let parent = self.buildParentRestorationActivity().userInfo {
            activity.addUserInfoEntries(from: parent)
        }
        if let node = self.file {
            activity.userInfo?[Self.FilePresenterKey] = node.identifier.rawValue
        }
        return activity
    }
    
    func buildParentRestorationActivity() -> NSUserActivity {
        let activity = self.makeActivity()
        if let parent = self.parentCoordinator?.buildStateRestorationActivity().userInfo {
            activity.addUserInfoEntries(from: parent)
        }
        return activity
    }
    
    static func restore(from userInfo: [AnyHashable: Any]?) -> RestorationInfo? {
        guard let fileRaw = userInfo?[Self.FilePresenterKey] as? NodeIdentifier.RawValue,
              let file = NodeIdentifier(rawValue: fileRaw),
              let parents = FinderCoordinator.restore(from: userInfo) else
        {
            return nil
        }
        
        return RestorationInfo(parents: parents, file: file)
    }
}
