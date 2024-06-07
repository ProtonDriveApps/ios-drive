// Copyright (c) 2024 Proton AG
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

final class CompleteRegisteringBackgroundTask: BackgroundTaskResource {
    private let task: BackgroundTaskResource
    private(set) var isCompleted = false

    init(task: BackgroundTaskResource) {
        self.task = task
        self.expirationHandler = expirationHandler
    }

    var identifier: String { task.identifier }

    var expirationHandler: (() -> Void)? {
        get { task.expirationHandler }
        set { task.expirationHandler = newValue }
    }

    func setTaskCompleted(success: Bool) {
        task.setTaskCompleted(success: success)
        isCompleted = true
    }

    deinit {
        Log.info("CompleteRegisteringBackgroundTask.deinit", domain: .backgroundTask)
    }
}
