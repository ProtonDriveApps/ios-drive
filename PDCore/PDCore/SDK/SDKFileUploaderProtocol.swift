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

@MainActor
public protocol SDKFileUploaderProtocol: AnyObject, TrackableUploadingQueue {
    var bytesCounterResource: BytesCounterResource { get }
    var failures: AnyPublisher<(AnyVolumeIdentifier, Error), Never> { get }
    var progresses: AnyPublisher<[UUID: Progress], Never> { get }
    var duplicated: AnyPublisher<(AnyVolumeIdentifier, String), Never> { get }

    /// Returns identifier or throws error.
    /// 
    /// Cancellation error is thrown in case of cancellation or pausing.
    /// In case of pausing:
    ///   - context is held in memory and can be resumed by calling `upload` again
    ///   - progresses keep the last observed value
    nonisolated func upload(identifier: AnyVolumeIdentifier) async throws -> AnyVolumeIdentifier
    #if os(iOS)
    nonisolated func upload(
        identifier: AnyVolumeIdentifier,
        duplicateAction: DuplicateUploadAction?
    ) async throws -> AnyVolumeIdentifier
    #endif
    func deleteUploadingFile(identifier: AnyVolumeIdentifier) async throws
    func cancel(identifier: AnyVolumeIdentifier) async
    func cancelAll() async
    func pause(identifier: AnyVolumeIdentifier) async
    func pauseAll() async
    func resumePausedUploads() async
    /// Includes paused uploads
    func activeUploadsCount() -> Int
}
