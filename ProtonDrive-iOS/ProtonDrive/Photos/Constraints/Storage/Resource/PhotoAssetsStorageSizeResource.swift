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

protocol PhotoAssetsStorageSizeResource {
    var size: AnyPublisher<Int, Never> { get }
    func execute()
    func cancel()
}

final class LocalPhotoAssetsStorageSizeResource: PhotoAssetsStorageSizeResource {
    private let updateResource: FolderUpdateResource
    private let sizeResource: FolderSizeResource
    private lazy var url = PDFileManager.cleartextPhotosCacheDirectory
    private var cancellables = Set<AnyCancellable>()
    private let sizeSubject = PassthroughSubject<Int, Never>()

    var size: AnyPublisher<Int, Never> {
        sizeSubject
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    init(updateResource: FolderUpdateResource, sizeResource: FolderSizeResource) {
        self.updateResource = updateResource
        self.sizeResource = sizeResource
        subscribeToUpdates()
    }

    private func subscribeToUpdates() {
        updateResource.updatePublisher
            .sink { [weak self] in
                self?.handleUpdate()
            }
            .store(in: &cancellables)
    }

    func execute() {
        updateResource.execute(with: url)
    }

    func cancel() {
        updateResource.cancel()
    }

    private func handleUpdate() {
        if let size = try? sizeResource.getSize(at: url) {
            sizeSubject.send(size)
        }
    }
}
