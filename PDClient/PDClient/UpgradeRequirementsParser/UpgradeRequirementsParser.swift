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

import Combine
import Foundation

public struct UpgradeRequirementsParser {
    static let featureHeader = "x-pm-drive-requirements"
    static let sdkHeader = "x-pm-drive-platform-requirements"
    static let sdkProductName = "sdk"
    static let sdkVersionPlistKey = "DRIVE_SDK_VERSION"

    var currentSDKVersion: Version? {
        guard
            let sdk = infoDictionary()?[Self.sdkVersionPlistKey] as? String,
            !sdk.isEmpty
        else { return nil }
        return Version(sdk)
    }

    private let infoDictionary: () -> [String: Any]?
    let upgradeRequirementsSubject: PassthroughSubject<UpgradeRequirementResult, Never> = .init()
    public var upgradeRequirementsPublisher: AnyPublisher<UpgradeRequirementResult, Never> {
        upgradeRequirementsSubject.removeDuplicates().receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }
    
    public init(infoDictionary: @escaping () -> [String: Any]? = { Bundle.main.infoDictionary }) {
        self.infoDictionary = infoDictionary
    }
    
    func parse(responseHeaders: [String: String]?) {
        let result = parse(featureRequirement: responseHeaders?[Self.featureHeader])
        parse(sdkRequirement: responseHeaders?[Self.sdkHeader], requirementResult: result)
        
        // At least one thing needs to be upgraded
        if result.hasAnyUpdate {
            upgradeRequirementsSubject.send(result)
        }
    }
    
    /// - Returns: [Produce name: needs to be upgraded]
    private func parse(featureRequirement: String?) -> UpgradeRequirementResult {
        let result = UpgradeRequirementResult()
        // Example value `drive=7 photos=4 docs=0`
        guard let featureRequirement else { return result }
        let produces = parseRequirements(featureRequirement, valueTransform: Int.init)
        
        for (product, features) in produces {
            // If a feature is not supported or unknown to the client
            // the client will show a warning message to the user
            switch product {
            case SupportedDriveFeature.product:
                let isOutdated = (features & ~SupportedDriveFeature.all.rawValue) != 0
                if isOutdated { result.insert(recommended: product) }
            default:
                result.insert(recommended: product)
            }
        }
        
        return result
    }
    
    private func parse(sdkRequirement: String?, requirementResult: UpgradeRequirementResult) {
        // Example value `suggested=0.0.2 required=0.0.1`
        guard let sdkRequirement else { return }
        let result = parseRequirements(sdkRequirement, valueTransform: Version.init)
        
        guard
            let suggested = result["suggested"],
            let required = result["required"],
            let currentSDKVersion
        else { return }
        
        if currentSDKVersion >= suggested {
            return
        } else if suggested > currentSDKVersion && currentSDKVersion >= required {
            // If the suggested platform version is not met
            // a notification recommending to update will be shown to the user.
            requirementResult.insert(recommended: Self.sdkProductName)
        } else {
            // If the required platform value is not met
            // a message warning the user that the application may not function properly will be shown to the user.
            requirementResult.insert(required: Self.sdkProductName)
        }
    }
    
    private func parseRequirements<T>(_ string: String, valueTransform: (String) -> T?) -> [String: T] {
        var result: [String: T] = [:]
        for pair in string.split(separator: " ") {
            let parts = pair.split(separator: "=")
            guard parts.count == 2 else {
                continue
            }

            let key = String(parts[0])
            let valueString = String(parts[1])
            guard let value = valueTransform(valueString) else {
                continue
            }

            // Keep the first value for duplicated keys to avoid crashes on malformed headers.
            if result[key] == nil {
                result[key] = value
            }
        }
        return result
    }
}
