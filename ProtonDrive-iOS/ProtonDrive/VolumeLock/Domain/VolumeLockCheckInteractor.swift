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

import PDCore

/// Checks the volume lock state when the app returns to the foreground
final class VolumeLockCheckInteractor: CommandInteractor {
    private weak var controller: VolumeLockController?

    init(controller: VolumeLockController) {
        self.controller = controller
    }

    func execute() {
        Task { @MainActor [weak controller] in
            await controller?.checkSilently()
        }
    }
}
