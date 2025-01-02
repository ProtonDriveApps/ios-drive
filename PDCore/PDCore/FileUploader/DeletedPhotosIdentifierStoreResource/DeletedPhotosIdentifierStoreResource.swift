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

public struct DeletedPhotoInfo {
    public let cloudIdentifier: String?
    public let error: PhotosFailureUserError?
}

public protocol DeletedPhotosIdentifierStoreResource {
    func increment(cloudIdentifier: String?, error: PhotosFailureUserError?)
    func getCount() -> Int
    func getCloudIdentifiersAndError() -> [DeletedPhotoInfo]
    func reset()

    var count: AnyPublisher<Int, Never> { get }
}

public final class InMemoryDeletedPhotosIdentifierStoreResource: DeletedPhotosIdentifierStoreResource {
    private let accessQueue = DispatchQueue(label: "InMemoryDeletedPhotosIdentifierStoreResource", attributes: .concurrent)
    private let subject = CurrentValueSubject<Int, Never>(0)
    private var cloudIdentifiersAndError: [DeletedPhotoInfo] = []

    public var count: AnyPublisher<Int, Never> {
        subject.eraseToAnyPublisher()
    }
    
    public init() { }

    public func increment(cloudIdentifier: String?, error: PhotosFailureUserError?) {
        Log.debug("Incrementing failed photos counter", domain: .photosProcessing)
        accessQueue.async(flags: .barrier) {
            if !self.cloudIdentifiersAndError.contains(where: { $0.cloudIdentifier == cloudIdentifier }) {
                self.cloudIdentifiersAndError.append(.init(cloudIdentifier: cloudIdentifier, error: error))
                self.subject.send(self.subject.value + 1)
            }
            
        }
     }

    public func getCount() -> Int {
        var result = 0
        accessQueue.sync {
            result = self.subject.value
        }
        Log.debug("Failed photos count: \(result)", domain: .photosProcessing)
        return result
    }

    public func reset() {
        Log.debug("Resetting failed photos count", domain: .photosProcessing)
        accessQueue.async(flags: .barrier) {
            self.subject.send(0)
            self.cloudIdentifiersAndError.removeAll()
        }
    }
    
    public func getCloudIdentifiersAndError() -> [DeletedPhotoInfo] {
        accessQueue.sync {
            cloudIdentifiersAndError
        }
    }
}
