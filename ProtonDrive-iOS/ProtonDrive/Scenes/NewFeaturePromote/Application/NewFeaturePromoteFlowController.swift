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
import PDCore
import UIKit
import PDUIComponents

protocol NewFeaturePromoteFlowControllerProtocol {
    func isAvailable() -> Bool
    func getFeatures() -> [NewFeature]
    func markPromoted()
}

final class NewFeaturePromoteFlowController: NewFeaturePromoteFlowControllerProtocol {
    private let settings: NewFeaturePromoteSettings
    private let featureFlagsController: FeatureFlagsControllerProtocol
    private let dateResource: DateResource
    
    init(
        settings: NewFeaturePromoteSettings,
        featureFlagsController: FeatureFlagsControllerProtocol,
        dateResource: DateResource
    ) {
        self.settings = settings
        self.featureFlagsController = featureFlagsController
        self.dateResource = dateResource
    }

    func isAvailable() -> Bool {
        return !getFeatures().isEmpty
    }

    func getFeatures() -> [NewFeature] {
        let promotedNewFeatures = settings.promotedNewFeatures.compactMap(NewFeature.init(rawValue:))
        return NewFeature.sortedCases
            .filter { feature in
                let isEnabled = isEnabled(feature: feature)
                let isPromoted = promotedNewFeatures.contains(feature)
                return isEnabled && !isPromoted
            }
    }

    func markPromoted() {
        let features = getFeatures()
        settings.append(promotedNewFeatures: features.map(\.rawValue))
    }

    private func isEnabled(feature: NewFeature) -> Bool {
        return !isExpired(feature: feature) && isFeatureFlagEnabled(feature: feature)
    }

    private func isExpired(feature: NewFeature) -> Bool {
        let expirationDate = getReleaseDate(for: feature).byAdding(.day, value: 30)
        return dateResource.getDate() > expirationDate
    }

    private func isFeatureFlagEnabled(feature: NewFeature) -> Bool {
        switch feature {
        case .doc:
            return featureFlagsController.hasProtonDocumentCreation
        case .sharing:
            return featureFlagsController.hasSharing
        }
    }

    private func getReleaseDate(for feature: NewFeature) -> Date {
        switch feature {
        case .doc, .sharing:
            // Fri Nov 01 2024 00:00:00 GMT+0000
            return Date(timeIntervalSince1970: 1730419200)
        }
    }
}
