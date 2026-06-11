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

import Combine
import Foundation

public struct SDKFileDownloadOptions: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let saveAsOfflineAvailable = Self(rawValue: 1 << 0)
}

@MainActor public protocol SDKFileDownloaderProtocol: DownloaderProtocol, TrackableDownloader {
    var failures: AnyPublisher<(AnyVolumeIdentifier, Error), Never> { get }
    var progresses: AnyPublisher<[AnyVolumeIdentifier: Progress], Never> { get }

    nonisolated func download(file identifier: AnyVolumeIdentifier) async throws
    nonisolated func download(file identifier: AnyVolumeIdentifier, options: SDKFileDownloadOptions) async throws
}
