// Copyright (c) 2025 Proton AG
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

#if DEBUG
import Foundation

public final class ExternalFeatureFlagOverrideCommandLineSerializer {
    public init() {}
    
    public func serialize(flags: [ExternalFeatureFlagOverride]) -> String {
        return flags
            .map { flag in
                let payload = flag.payload.map {
                    Data($0.utf8).base64EncodedString()
                }
                return "\(flag.flag.rawValue):\(flag.value):\(payload ?? "")"
            }
            .joined(separator: ",")
    }

    public func deserialize(from string: String) -> [ExternalFeatureFlagOverride] {
        let components = string.split(separator: ",")
        return components.compactMap { parseOverride(from: String($0)) }
    }

    private func parseOverride(from string: String) -> ExternalFeatureFlagOverride? {
        let components = string.components(separatedBy: ":")
        guard components.count == 3 else {
            return nil
        }
        guard let flag = ExternalFeatureFlag(rawValue: components[0]) else {
            return nil
        }
        guard let value = Bool(components[1]) else {
            return nil
        }
        var deserializedPayload: String?
        let payloadData = components[2]
        if !payloadData.isEmpty, let data = Data(base64Encoded: payloadData) {
            deserializedPayload = String(data: data, encoding: .utf8)
        }
        return ExternalFeatureFlagOverride(flag: flag, value: value, payload: deserializedPayload)
    }
}
#endif
