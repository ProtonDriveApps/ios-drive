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

import PDCore

final class ForegroundTransitionFactory {
    func makeController(
        tower: Tower,
        pickerResource: PickerResource,
        populatedStateController: PopulatedStateControllerProtocol,
        lockedStateController: LockedStateControllerProtocol
    ) -> ForegroundTransitionController {
        let interactors: [CommandInteractor] = [
            ChildSessionInteractor(sessionCommunicator: tower.sessionCommunicator)
        ]

        let populatedInteractors: [CommandInteractor] = [
            InterruptedUploadsInteractor(
                storage: tower.storage,
                fileUploader: tower.fileUploader,
                tower: tower
            ),
            InterruptedImportsInteractor(resource: pickerResource),
        ]

        let applicationStateResource = iOSApplicationRunningStateResource()
        /// Resumes multiple operations after app goes to foreground
        /// 1. makes sure we have up to date child session
        /// 2. when DB is unlocked, it auto resumes interrupted file uploads & imports
        return ForegroundTransitionController(
            applicationStateController: ConcreteApplicationStateController(stateResource: iOSApplicationRunningStateResource()),
            interactors: interactors,
            populatedInteractors: populatedInteractors,
            populatedStateController: populatedStateController,
            lockedStateController: lockedStateController
        )
    }
}
