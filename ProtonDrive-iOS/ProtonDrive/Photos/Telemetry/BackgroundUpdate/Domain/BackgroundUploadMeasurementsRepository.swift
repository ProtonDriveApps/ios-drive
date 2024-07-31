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

protocol BackgroundUploadMeasurementsRepositoryProtocol {
    func getMeasurements() -> BackgroundUploadMeasurements
    func reset()
}

struct BackgroundUploadMeasurements: Equatable {
    let startedFilesCount: Int
    let failedFilesCount: Int
    let succeededFilesCount: Int
    let succeededBlocksCount: Int
    let state: BackgroundTaskResultState?
}

/// Implementation combining upload related tracking, as well as means to read and reset the values.
/// All functions are threadsafe and sync, so can be called on an arbitrary queue.
/// All accessors run on the same queue to reduce the number of queues.
final class BackgroundUploadMeasurementsRepository: FileUploadFilesMeasurementRepositoryProtocol, FileUploadBlocksMeasurementRepositoryProtocol, BackgroundUploadMeasurementsRepositoryProtocol, BackgroundTaskResultStateRepositoryProtocol {
    @ThreadSafe private var uploadIds: Set<String>
    @ThreadSafe private var succeededFilesCount: Int
    @ThreadSafe private var failedFilesCount: Int
    @ThreadSafe private var succeededBlocksCount: Int
    @ThreadSafe private var state: BackgroundTaskResultState?

    init() {
        // Since the dispatch queue is private, it's safe to use `sync` and `async(barrier)` in the property wrappers.
        let dispatchQueue = DispatchQueue(label: "BackgroundUploadMeasurementsRepository")
        _uploadIds = ThreadSafe(wrappedValue: [], queue: dispatchQueue)
        _succeededFilesCount = ThreadSafe(wrappedValue: 0, queue: dispatchQueue)
        _failedFilesCount = ThreadSafe(wrappedValue: 0, queue: dispatchQueue)
        _succeededBlocksCount = ThreadSafe(wrappedValue: 0, queue: dispatchQueue)
        _state = ThreadSafe(wrappedValue: nil, queue: dispatchQueue)
    }

    func trackFileUploadStart(id: String) {
        Log.debug("\(Self.self).trackFileUploadStart", domain: .telemetry)
        uploadIds.insert(id)
    }

    func trackFileSuccess() {
        Log.debug("\(Self.self).trackFileSuccess", domain: .telemetry)
        succeededFilesCount += 1
    }

    func trackFileFailure() {
        Log.debug("\(Self.self).trackFileFailure", domain: .telemetry)
        failedFilesCount += 1
    }

    func trackBlockUploadSuccess() {
        Log.debug("\(Self.self).trackBlockUploadSuccess", domain: .telemetry)
        succeededBlocksCount += 1
    }

    func reset() {
        Log.debug("\(Self.self).reset", domain: .telemetry)
        uploadIds.removeAll()
        succeededFilesCount = 0
        failedFilesCount = 0
        succeededBlocksCount = 0
        state = nil
    }

    func getMeasurements() -> BackgroundUploadMeasurements {
        Log.debug("\(Self.self).getMeasurements", domain: .telemetry)
        return BackgroundUploadMeasurements(
            startedFilesCount: uploadIds.count,
            failedFilesCount: failedFilesCount,
            succeededFilesCount: succeededFilesCount, 
            succeededBlocksCount: succeededBlocksCount,
            state: state
        )
    }

    func setState(_ state: BackgroundTaskResultState) {
        Log.debug("\(Self.self).setResult, \(state)", domain: .telemetry)
        self.state = state
    }
}
