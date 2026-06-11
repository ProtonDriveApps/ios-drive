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

import Combine
import Foundation
import PDCore

public protocol PhotoAssetsStorageConstraintInteractor {
    var constraint: AnyPublisher<Bool, Never> { get }
    func execute()
    func cancel()
}

/// We measure the storage consumption and if the usage is bigger than Constants.photosAssetsMaximalFolderSize we pause the processing.
/// The storage is cleaned up after upload, so when sufficient number of photos is uploaded the constraint is lifted again.
public final class LocalPhotoAssetsStorageConstraintInteractor: PhotoAssetsStorageConstraintInteractor {
    static let photosAssetsMaximalFolderSize = 200_000_000 // bytes count

    private let resource: PhotoAssetsStorageSizeResource
    private var cancellables = Set<AnyCancellable>()
    private let constraintSubject = PassthroughSubject<Bool, Never>()

    public var constraint: AnyPublisher<Bool, Never> {
        constraintSubject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    public init(resource: PhotoAssetsStorageSizeResource) {
        self.resource = resource
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        resource.size
            .map { size in
                let isConstrained = size > Self.photosAssetsMaximalFolderSize
                if isConstrained {
                    Log.debug("Pending uploading size is too big: \(size)", domain: .storage)
                }
                return isConstrained
            }
            .removeDuplicates()
            .sink { [weak self] isConstrained in
                self?.constraintSubject.send(isConstrained)
            }
            .store(in: &cancellables)
    }

    public func execute() {
        resource.execute()
    }

    public func cancel() {
        resource.cancel()
    }
}
