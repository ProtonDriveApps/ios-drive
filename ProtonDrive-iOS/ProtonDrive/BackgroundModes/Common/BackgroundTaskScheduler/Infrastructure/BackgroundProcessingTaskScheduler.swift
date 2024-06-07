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
import BackgroundTasks

public final class BackgroundProcessingTaskScheduler: BackgroundTaskScheduler {
    public typealias TaskIdentifier = String
    private let id: String
    private let submitTask: (BGProcessingTaskRequest) throws -> Void
    private let cancelTask: (TaskIdentifier) -> Void
    private let date: () -> Date?

    public init(
        id: String,
        submitTask: @escaping (BGProcessingTaskRequest) throws -> Void,
        cancelTask: @escaping (TaskIdentifier) -> Void,
        date: @escaping () -> Date?
    ) {
        self.id = id
        self.submitTask = submitTask
        self.cancelTask = cancelTask
        self.date = date
    }

    public func schedule() {
        let request = BGProcessingTaskRequest(identifier: id)
        request.earliestBeginDate = date()
        request.requiresExternalPower = false
        request.requiresNetworkConnectivity = true

        do {
            try submitTask(request)
            Log.info("1️⃣🗓️ Did schedule \(id) BG task.", domain: .backgroundTask)
        } catch {
            Log.error("1️⃣🗓️ Could not schedule \(id) BG task: \(error).", domain: .backgroundTask)
        }
    }

    public func cancel() {
        Log.info("1️⃣🗓️🚫 did cancel \(id) BG task", domain: .backgroundTask)
        cancelTask(id)
    }
}
