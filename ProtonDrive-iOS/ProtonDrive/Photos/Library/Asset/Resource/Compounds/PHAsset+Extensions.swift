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

import Photos
import PDCore

extension PHAsset {
    
    /// - Returns: (hasAdjustmentData, adjustmentDate)
    func getAdjustmentDate() async -> (Bool, Date?) {
        await withCheckedContinuation { (continuation: CheckedContinuation<(Bool, Date?), Never>) in
            guard
                let adjustmentDataResource = PHAssetResource
                    .assetResources(for: self)
                    .first(where: { $0.type == .adjustmentData })
            else {
                continuation.resume(with: .success((false, nil)))
                return
            }
            
            // While reading (or downloading) asset resource data
            // Photos calls your handler block at least once, progressively providing chunks of data.
            var adjustmentData = Data()
            PHAssetResourceManager.default()
                .requestData(for: adjustmentDataResource, options: nil) { data in
                    adjustmentData.append(data)
                } completionHandler: { error in
                    if let error {
                        Log.error("Query adjustmentData error: \(error.localizedDescription)", domain: .photosProcessing)
                        continuation.resume(with: .success((true, nil)))
                    } else {
                        let result = try? PropertyListDecoder().decode(AdjustmentData.self, from: adjustmentData)
                        Log.info("Queried adjustmentData contains timestamp \(result != nil)", domain: .photosProcessing)
                        continuation.resume(with: .success((true, result?.adjustmentTimestamp)))
                    }
                }
        }
    }
}

private struct AdjustmentData: Decodable {
    let adjustmentTimestamp: Date
}
