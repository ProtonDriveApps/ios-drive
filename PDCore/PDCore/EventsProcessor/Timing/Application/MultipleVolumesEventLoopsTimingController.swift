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

import Combine
import Foundation
import PMEventsManager

final class MultipleVolumesEventLoopsTimingController: EventLoopsTimingController {
    private let volumeIdsController: VolumeIdsControllerProtocol
    private let dateResource: DateResource
    private let executionPolicy: EventLoopsExecutionPolicyProtocol
    private let stateResource: ApplicationRunningStateResource
    private var executionHistory = [VolumeID: Date]()
    private var cancellables = Set<AnyCancellable>()

    init(volumeIdsController: VolumeIdsControllerProtocol, dateResource: DateResource, executionPolicy: EventLoopsExecutionPolicyProtocol, stateResource: ApplicationRunningStateResource) {
        self.volumeIdsController = volumeIdsController
        self.dateResource = dateResource
        self.executionPolicy = executionPolicy
        self.stateResource = stateResource
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        volumeIdsController.update
            .sink { [weak self] in
                self?.handleUpdate()
            }
            .store(in: &cancellables)
    }

    private func handleUpdate() {
        let volumes = volumeIdsController.getVolumes()
        volumes.ownVolumes.forEach { fillInitialDate(for: $0) }
        volumes.sharedVolumes.forEach { fillInitialDate(for: $0.id) }
    }

    private func fillInitialDate(for volumeId: VolumeID) {
        if executionHistory[volumeId] == nil {
            // Store the initial time when volume was registered. The delays are counter from this point forward
            executionHistory[volumeId] = dateResource.getDate()
        }
    }

    func getInterval() -> Double {
        return 30
    }

    func getReadyLoops(possible: [LoopID]) -> [LoopID] {
        let volumes = volumeIdsController.getVolumes()
        let executionData = EventLoopsExecutionData(
            ownLoops: volumes.ownVolumes.compactMap {
                makeLoopData(volumeId: $0, type: .own)
            },
            sharedLoops: volumes.sharedVolumes.compactMap { volume in
                let type: EventLoopsExecutionData.LoopType = volume.isActive ? .activeShared : .inactiveShared
                return makeLoopData(volumeId: volume.id, type: type)
            },
            possibleIds: possible
        )
        return executionPolicy.getAllowedVolumeIds(with: executionData)
    }

    private func makeLoopData(volumeId: VolumeID?, type: EventLoopsExecutionData.LoopType) -> EventLoopsExecutionData.LoopData? {
        guard let volumeId else {
            Log.error("Inconsistent data", error: nil, domain: .events)
            return nil
        }
        guard let lastDate = executionHistory[volumeId] else {
            Log.error("Inconsistent dates", error: nil, domain: .events)
            return nil
        }

        return EventLoopsExecutionData.LoopData(
            volumeId: volumeId,
            type: type,
            lastDate: lastDate,
            currentDate: dateResource.getDate(),
            isRunningInBackground: stateResource.getState() == .background
        )
    }

    func setExecutedLoops(loopIds: [LoopID]) {
        loopIds.forEach {
            // Mark the execution time
            executionHistory[$0] = dateResource.getDate()
        }
    }

    func updateHistoryForForcePolling(volumeIDs: [String]) {
        if volumeIDs.isEmpty {
            executionHistory.forEach { (key, _) in
                executionHistory[key] = Date(timeIntervalSinceReferenceDate: 0)
            }
        } else {
            volumeIDs.forEach { executionHistory[$0] = Date(timeIntervalSinceReferenceDate: 0) }
        }
    }
}
