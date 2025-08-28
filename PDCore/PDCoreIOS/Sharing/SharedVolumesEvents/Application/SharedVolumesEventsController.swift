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
import PDCore

// Single point for managing shared volumes events
public protocol SharedVolumesEventsControllerProtocol {
    func appendVolumeIds(_ volumeIds: [VolumeID])
    func removeVolumeIds(_ volumeIds: [VolumeID])
}

public final class SharedVolumesEventsController: SharedVolumesEventsControllerProtocol {
    private let featureFlagsController: FeatureFlagsControllerProtocol
    private let eventsManager: EventsSystemManager
    private let volumeIdsController: SharedVolumeIdsController
    private var cancellables = Set<AnyCancellable>()

    public init(featureFlagsController: FeatureFlagsControllerProtocol, eventsManager: EventsSystemManager, volumeIdsController: SharedVolumeIdsController) {
        self.featureFlagsController = featureFlagsController
        self.eventsManager = eventsManager
        self.volumeIdsController = volumeIdsController
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        // When `hasSharing` is toggled off, stop all shared volumes event loops
        featureFlagsController.updatePublisher
            .filter { [weak self] in
                (self?.featureFlagsController.hasSharing == false)
            }
            .sink { [weak self] in
                self?.eventsManager.removeAllSharedVolumesEventLoops()
            }
            .store(in: &cancellables)
    }

    public func appendVolumeIds(_ volumeIds: [VolumeID]) {
        eventsManager.appendSharedVolumesEventLoops(volumeIds: volumeIds)
    }

    public func removeVolumeIds(_ volumeIds: [VolumeID]) {
        eventsManager.removeSharedVolumesEventLoops(volumeIds: volumeIds)
    }
}
