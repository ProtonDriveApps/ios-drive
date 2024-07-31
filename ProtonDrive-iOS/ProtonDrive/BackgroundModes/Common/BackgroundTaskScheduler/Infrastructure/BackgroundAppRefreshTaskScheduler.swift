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

public final class BackgroundAppRefreshTaskScheduler: BackgroundTaskScheduler {
    public typealias TaskIdentifier = String
    private let id: String
    private let submitTask: (BGAppRefreshTaskRequest) throws -> Void
    private let cancelTask: (TaskIdentifier) -> Void
    private let date: () -> Date?

    private var iteration = 1

    public init(
        id: String,
        submitTask: @escaping (BGAppRefreshTaskRequest) throws -> Void,
        cancelTask: @escaping (TaskIdentifier) -> Void,
        date: @escaping () -> Date?
    ) {
        self.id = id
        self.submitTask = submitTask
        self.cancelTask = cancelTask
        self.date = date
    }

    public func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: id)
        request.earliestBeginDate = date()?.byAdding(.day, value: calculate(2, power: iteration))

        do {
            try submitTask(request)
            iteration += 1
            Log.info("1️⃣🗓️ Did schedule \(id) BG task.", domain: .backgroundTask)
        } catch {
            Log.error("1️⃣🗓️ Could not schedule \(id) BG task: \(error).", domain: .backgroundTask)
        }
    }

    private func calculate(_ base: Int, power exponent: Int) -> Int {
        Int(pow(Double(base), Double(exponent)))
    }

    public func cancel() {
        Log.info("1️⃣🗓️🚫 did cancel \(id) BG task", domain: .backgroundTask)
        cancelTask(id)
        iteration = 1
    }
}
