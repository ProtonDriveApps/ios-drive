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
import Combine

public extension FileUploader {

    typealias OperationID = UUID
    typealias CurrentProgress = Progress
    
    var queue: OperationQueue {
        processingQueue
    }

    private func errorStreamToErrorPublisher<Hashable, T>() -> AnyPublisher<[Hashable: T], Error> {
        errorStream
            .setFailureType(to: Error.self)
            .tryMap { throw $0 }
            .map { [:] }
            .eraseToAnyPublisher()
    }

    func progressPublisher() -> AnyPublisher<[OperationID: CurrentProgress], Error> {
        queue
            .publisher(for: \.operations)
            .compactMap { operations in
                operations
                    .compactMap { $0 as? FileUploaderOperation }
                    .reduce(into: [OperationID: CurrentProgress]()) { partialResult, op in
                        partialResult[op.id] = op.progress
                    }
            }
            .removeDuplicates()
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
            .merge(with: errorStreamToErrorPublisher())
            .eraseToAnyPublisher()
    }

}
