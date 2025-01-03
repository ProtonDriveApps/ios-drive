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

import PDCore

struct PhotoUploadTelemetryData {
    let isSuccess: Bool
    let kilobytes: Double
    let duration: Double
    let isInitialBackup: Bool
    let isBackgroundTask: Bool
    let mediaType: PhotoUploadMediaType
}

protocol PhotoUploadDoneTelemetryDataFactory {
    func makeData(with data: PhotoUploadTelemetryData) -> TelemetryData
}

final class ConcretePhotoUploadDoneTelemetryDataFactory: PhotoUploadDoneTelemetryDataFactory {
    private let userInfoFactory: PhotosTelemetryUserInfoFactory
    private let connectionFactory: PhotosTelemetryConnectionFactoryProtocol

    init(userInfoFactory: PhotosTelemetryUserInfoFactory, connectionFactory: PhotosTelemetryConnectionFactoryProtocol) {
        self.userInfoFactory = userInfoFactory
        self.connectionFactory = connectionFactory
    }

    func makeData(with data: PhotoUploadTelemetryData) -> TelemetryData {
        return TelemetryData(
            group: .photos,
            event: .uploadDone,
            values: makeValues(from: data),
            dimensions: makeDimensions(from: data)
        )
    }

    private func makeValues(from data: PhotoUploadTelemetryData) -> [String: Double] {
        return [
            "kilobytes_uploaded": data.kilobytes,
            "duration_seconds": data.duration,
        ]
    }

    private func makeDimensions(from data: PhotoUploadTelemetryData) -> [String: String] {
        var dimensions = userInfoFactory.makeDimensions()
        dimensions["is_initial_backup"] = data.isInitialBackup ? "yes" : "no"
        dimensions["is_background_task"] = data.isBackgroundTask ? "yes" : "no"
        dimensions["result"] = data.isSuccess ? "completed" : "failed"
        dimensions["media_type"] = makeMediaType(with: data.mediaType)
        dimensions.merge(connectionFactory.makeDimensions(), uniquingKeysWith: { current, _ in current })
        return dimensions
    }

    private func makeMediaType(with type: PhotoUploadMediaType) -> String {
        switch type {
        case .photo:
            return "photo"
        case .video:
            return "video"
        }
    }

    private func makeConnection(with interface: NetworkState.Interface?) -> String {
        switch interface {
        case .cellular:
            return "cellular"
        case .wifi:
            return "wifi"
        case .wired:
            return "wired"
        case .loopback:
            return "loopback"
        case .other, nil:
            return "other"
        }
    }
}
