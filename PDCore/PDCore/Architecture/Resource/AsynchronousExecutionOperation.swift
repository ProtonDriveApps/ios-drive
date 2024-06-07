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

public protocol AsynchronousExecution {
    func execute() async
}

open class AsynchronousExecutionOperation: AsynchronousOperation {
    private let execution: AsynchronousExecution
    private var task: Task<Void, Never>?

    public init(execution: AsynchronousExecution) {
        self.execution = execution
    }

    override public func main() {
        guard !isCancelled else {
            return
        }

        task = Task(priority: .low) { [weak self] in
            guard self?.isCancelled == false else { return }
            await self?.execution.execute()
            self?.state = .finished
        }
    }

    override open func cancel() {
        task?.cancel()
        super.cancel()
    }
}

public class AggregatedAsynchronousExecution: AsynchronousExecution {
    private let executions: [AsynchronousExecution]

    public init(executions: [AsynchronousExecution]) {
        self.executions = executions
    }

    public func execute() async {
        await executions.forEach { await $0.execute() }
    }
}
