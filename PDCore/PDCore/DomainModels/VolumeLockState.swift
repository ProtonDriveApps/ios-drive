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

import Foundation

public typealias VolumeLockStateInputs = (cachedTree: (shareID: String, volumeID: String)?, volumes: [VolumeMeta])

public enum VolumeLockState: Equatable {
    /// Happy path: the user has a cached volume that's been reported as active via the API.
    case cachedVolumeActive
    /// There's no volume in the metadata DB. Usually means that the user is signed out.
    case noCachedVolume
    /// User doesn't have any volumes with an active main share available. Leads to the locked
    /// state.
    case noActiveMainVolume
    /// The volume is active again (typically recovered after a lock) but under a different root
    /// share, so the cached tree no longer matches it and must be replaced.
    case cachedVolumeStale
    /// Normally another account's cache left by a user switch, owned by the login flow — but a
    /// deleted-and-recreated volume also lands here, so the name stays literal.
    case cachedVolumeUnlisted

    public static func resolve(from inputs: VolumeLockStateInputs) -> VolumeLockState {
        guard let cached = inputs.cachedTree else { return .noCachedVolume }
        guard let activeMainShare = inputs.volumes.first(where: { $0.type == .main && $0.state == .active }) else {
            return .noActiveMainVolume
        }
        if activeMainShare.volumeID == cached.volumeID && activeMainShare.share.shareID == cached.shareID {
            return .cachedVolumeActive
        }
        let cachedVolumeStillListed = inputs.volumes.contains { $0.volumeID == cached.volumeID }
        return cachedVolumeStillListed ? .cachedVolumeStale : .cachedVolumeUnlisted
    }
}
