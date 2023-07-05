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
import CoreData

class NameResolvingFileDraftCreatorOperationFactory: DefaultFileDraftCreatorOperationFactory {
    let hashChecker: AvailableHashChecker
    let moc: NSManagedObjectContext

    init(
        hashChecker: AvailableHashChecker,
        fileDraftCreator: CloudFileDraftCreator,
        sessionVault: SessionVault,
        moc: NSManagedObjectContext
    ) {
        self.hashChecker = hashChecker
        self.moc = moc
        
        super.init(fileDraftCreator: fileDraftCreator, sessionVault: sessionVault)
    }

    override func makeFileDraftCreator() -> FileDraftCreator {
        let nameDiscoverer = makeNameDiscoverer()
        let defaultUploader = DefaultFileDraftCreator(cloudFileCreator: fileDraftCreator, signersKitFactory: sessionVault)
        return NameClashResolvingFileDraftCreator(
            fileDraftCreator: defaultUploader,
            validNameDiscoverer: nameDiscoverer,
            signersKitFactory: sessionVault,
            moc: moc
        )
    }

    func makeNameDiscoverer() -> RecursiveValidNameDiscoverer {
        RecursiveValidNameDiscoverer(hashChecker: hashChecker)
    }

}
