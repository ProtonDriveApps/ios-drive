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

typealias EventLoopPriorityData = EventLoopsExecutionData.LoopData

enum EventLoopExecutionPriority: Comparable {
    case high
    case low(priority: Int) // The bigger number the higher priority

    private var sortValue: Int {
        switch self {
        case .high:
            Int.max
        case .low(let priority):
            priority
        }
    }

    static func < (lhs: EventLoopExecutionPriority, rhs: EventLoopExecutionPriority) -> Bool {
        return lhs.sortValue < rhs.sortValue
    }
}

protocol EventLoopPriorityPolicyProtocol {
    func getPriority(with data: EventLoopPriorityData) -> EventLoopExecutionPriority?
}

final class EventLoopPriorityPolicy: EventLoopPriorityPolicyProtocol {
    func getPriority(with data: EventLoopPriorityData) -> EventLoopExecutionPriority? {
        switch data.type {
        case .main:
            return getMainVolumePriority(with: data)
        case .activeShared:
            return getSharedVolumePriority(with: data, isActive: true)
        case .inactiveShared:
            return getSharedVolumePriority(with: data, isActive: false)
        }
    }

    private func getMainVolumePriority(with data: EventLoopPriorityData) -> EventLoopExecutionPriority? {
        if data.isRunningInBackground {
            // background
            return getPriority(data: data, tresholdDelayInSeconds: 1800, isHighPriority: true)
        } else {
            // foreground
            return getPriority(data: data, tresholdDelayInSeconds: 30, isHighPriority: true)
        }
    }

    func getSharedVolumePriority(with data: EventLoopPriorityData, isActive: Bool) -> EventLoopExecutionPriority? {
        if data.isRunningInBackground {
            // background
            return getPriority(data: data, tresholdDelayInSeconds: 86400, isHighPriority: false)
        } else if isActive {
            // foreground & active
            return getPriority(data: data, tresholdDelayInSeconds: 30, isHighPriority: true)
        } else {
            // foreground
            return getPriority(data: data, tresholdDelayInSeconds: 600, isHighPriority: false)
        }
    }

    private func getPriority(
        data: EventLoopPriorityData,
        tresholdDelayInSeconds: Double,
        isHighPriority: Bool
    ) -> EventLoopExecutionPriority? {
        let interval = data.currentDate.timeIntervalSince(data.lastDate)
        // Comparing two Doubles here, let's round to be sure
        let secondsSinceTreshold = Int(round(interval - tresholdDelayInSeconds))
        guard secondsSinceTreshold >= 0 else {
            // current date doesn't satisfy the treshold delay
            return nil
        }

        if isHighPriority {
            // This is priority volume and should be polled right away
            return .high
        } else {
            // Lower priority volume, but current date already satisfies the treshold delay
            return .low(priority: secondsSinceTreshold)
        }
    }
}
