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

import Foundation

struct EventLoopsExecutionData {
    let mainLoop: LoopData?
    let sharedLoops: [LoopData]
    let possibleIds: [String]

    struct LoopData {
        let volumeId: VolumeID
        let type: LoopType
        let lastDate: Date
        let currentDate: Date
        let isRunningInBackground: Bool
    }

    enum LoopType {
        case main
        case activeShared
        case inactiveShared
    }
}

protocol EventLoopsExecutionPolicyProtocol {
    func getAllowedVolumeIds(with data: EventLoopsExecutionData) -> [VolumeID]
}

final class EventLoopsExecutionPolicy: EventLoopsExecutionPolicyProtocol {
    private let loopPolicy: EventLoopPriorityPolicyProtocol

    init(loopPolicy: EventLoopPriorityPolicyProtocol) {
        self.loopPolicy = loopPolicy
    }

    func getAllowedVolumeIds(with data: EventLoopsExecutionData) -> [VolumeID] {
        // Only one main loop and one shared loop can be returned at a time
        // Main loop can be executed if its priority is non-nil
        // Same for shared loop, plus the highest priority one gets the privilege
        var resultLoops = [VolumeID]()

        // Main loop
        if let mainLoop = data.mainLoop, getPriority(data: data, loop: mainLoop) != nil {
            resultLoops.append(mainLoop.volumeId)
        }

        // Shared loop
        let sortedSharedLoops = data.sharedLoops
            .compactMap { loop in
                if let priority = getPriority(data: data, loop: loop) {
                    return (priority, loop)
                } else {
                    return nil
                }
            }
            .sorted(by: { $0.0 > $1.0 }) // sorted by priority
        if let highestPrioritySharedLoop = sortedSharedLoops.first?.1 {
            resultLoops.append(highestPrioritySharedLoop.volumeId)
        }
        return resultLoops
    }

    private func getPriority(data: EventLoopsExecutionData, loop: EventLoopsExecutionData.LoopData) -> EventLoopExecutionPriority? {
        guard data.possibleIds.contains(loop.volumeId) else {
            return nil
        }

        return loopPolicy.getPriority(with: loop)
    }
}
