// Copyright (c) 2023 Proton AG
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

public protocol UploadOperation: IdentifiableOperation, OperationWithProgress, RecordableOperation { }

public protocol DownloadOperation: OperationWithProgress {
    var identifier: AnyVolumeIdentifier { get }
}

public protocol OperationWithProgress where Self: Operation {
    var progress: Progress { get }
    
    func cancel()
}

extension OperationWithProgress {
    func progressTracker(direction: ProgressTracker.Direction) -> ProgressTracker {
        return .init(operation: self, direction: direction)
    }
    
    func fingerprint(progress: Progress, _ id: URL?) {
        progress.fileURL = id
    }
}

public protocol IdentifiableOperation: Operation, Identifiable {
    var id: UUID { get }
}

public protocol RecordableOperation where Self: Operation {
    var recordingName: String { get }

    func record()
}

public extension RecordableOperation where Self: UploadOperation {
    var recordingName: String { "uploading" }

    func record() {
//        Uncomment next line for recording coredata object for tests
//        PDFileManager.copyMetadata(stage: recordingName)
    }
}
