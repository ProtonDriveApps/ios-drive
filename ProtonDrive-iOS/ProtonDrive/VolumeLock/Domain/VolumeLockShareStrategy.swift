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

import PDClient

protocol VolumeLockShareStrategy {
    func isVolumeLocked(shares: [ListSharesEndpoint.Response.Share]) -> Bool
    func lockedShares(in shares: [ListSharesEndpoint.Response.Share]) -> [ListSharesEndpoint.Response.Share]
    func lockedShareIDs(in shares: [ListSharesEndpoint.Response.Share]) -> Set<String>
    func isVolumeUnlocked(shares: [ListSharesEndpoint.Response.Share]) -> Bool
}

struct DefaultVolumeLockShareStrategy: VolumeLockShareStrategy {
    func isVolumeLocked(shares: [ListSharesEndpoint.Response.Share]) -> Bool {
        !lockedShares(in: shares).isEmpty
    }

    func lockedShares(in shares: [ListSharesEndpoint.Response.Share]) -> [ListSharesEndpoint.Response.Share] {
        shares.filter(isLockedShare)
    }

    func lockedShareIDs(in shares: [ListSharesEndpoint.Response.Share]) -> Set<String> {
        Set(lockedShares(in: shares).map(\.shareID))
    }

    func isVolumeUnlocked(shares: [ListSharesEndpoint.Response.Share]) -> Bool {
        guard
            let mainShare = shares.first(where: { $0.type == .main && !isLockedShare($0) })
        else { return false }
        return mainShare.state == .active
    }

    private func isLockedShare(_ share: ListSharesEndpoint.Response.Share) -> Bool {
        share.locked == true || share.state == .locked
    }
}
