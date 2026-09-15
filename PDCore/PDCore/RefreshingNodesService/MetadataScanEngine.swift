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

/// The metadata scan used by the full resync. Concrete engines (v1, v2) are selected at runtime by
/// the `driveSyncMetadataScanV2Enabled` flag: v1 is the default, v2 runs only when the flag is on.
protocol MetadataScanEngine {
    // volumeID is supplied by the caller because a node's own volumeID is empty on macOS; v2 needs it for
    // the volume-based endpoints, v1 ignores it.
    func scanMetadata(
        root: Folder,
        volumeID: String,
        resume: Bool,
        cancelToken: CancelToken?,
        onNodesRefreshed: @MainActor @escaping (_ saved: Int, _ total: Int?) -> Void
    ) async throws -> RefreshedNodesReport
}
