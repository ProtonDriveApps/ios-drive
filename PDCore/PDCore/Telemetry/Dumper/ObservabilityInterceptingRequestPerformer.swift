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

#if os(macOS)

import Foundation
import ProtonCoreNetworking
import ProtonCoreServices

public final class ObservabilityInterceptingRequestPerformer: RequestPerforming {
    private let wrapped: RequestPerforming
    private let fileWriter: ObservabilityEventWriting
    private let isDetailedLoggingEnabled: () -> Bool

    private static let observabilityPath = "/data/v1/metrics"

    public init(
        wrapped: RequestPerforming,
        fileWriter: ObservabilityEventWriting,
        isDetailedLoggingEnabled: @escaping () -> Bool
    ) {
        self.wrapped = wrapped
        self.fileWriter = fileWriter
        self.isDetailedLoggingEnabled = isDetailedLoggingEnabled
    }

    public func performRequest(
        request: Request,
        parameters: Any?,
        headers: [String: Any]?,
        onDataTaskCreated: @escaping (URLSessionDataTask) -> Void,
        jsonCompletion: JSONCompletion?
    ) {
        interceptObservabilityIfNeeded(request: request, parameters: parameters)
        wrapped.performRequest(
            request: request,
            parameters: parameters,
            headers: headers,
            onDataTaskCreated: onDataTaskCreated,
            jsonCompletion: jsonCompletion
        )
    }

    private func interceptObservabilityIfNeeded(request: Request, parameters: Any?) {
        guard isDetailedLoggingEnabled() else { return }
        guard request.path == Self.observabilityPath else { return }
        guard let parameters = parameters else { return }

        extractAndWriteObservabilityEntries(from: parameters)
    }

    private func extractAndWriteObservabilityEntries(from parameters: Any?) {
        guard let params = parameters as? [String: Any] else { return }

        if let metricsArray = params["Metrics"] as? [[String: Any]] {
            for metric in metricsArray {
                writeObservabilityEntry(from: metric)
            }
        }
    }

    private func writeObservabilityEntry(from metric: [String: Any]) {
        let name = metric["Name"] as? String ?? ""
        let version = metric["Version"] as? Int ?? 0

        var value: Double = 0
        var labels: [String: String] = [:]

        if let data = metric["Data"] as? [String: Any] {
            if let intValue = data["Value"] as? Int {
                value = Double(intValue)
            } else if let doubleValue = data["Value"] as? Double {
                value = doubleValue
            }

            if let labelDict = data["Labels"] as? [String: Any] {
                for (key, labelValue) in labelDict {
                    if let stringValue = labelValue as? String {
                        labels[key] = stringValue
                    } else {
                        labels[key] = String(describing: labelValue)
                    }
                }
            }
        }

        let entry = ObservabilityEventEntry(
            source: "observability",
            group: name,
            event: "v\(version)",
            values: ["value": value],
            dimensions: labels
        )

        fileWriter.write(entry)
    }
}

#endif
