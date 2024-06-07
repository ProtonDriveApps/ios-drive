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

final class UploadingPhotoAssetsStorageSizeResource: PhotoAssetsStorageSizeResource {
    private let observer: FetchedResultsControllerObserver<Photo>
    private var subject = PassthroughSubject<Int, Never>()
    private var subscription: AnyCancellable?

    var size: AnyPublisher<Int, Never> {
        subject.eraseToAnyPublisher()
    }

    init(observer: FetchedResultsControllerObserver<Photo>) {
        self.observer = observer
    }

    func execute() {
        cancel()
        subscription = observer
            .getPublisher()
            .compactMap { [weak self] photos in
                self?.getSize(from: photos)
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] size in
                self?.subject.send(size)
            }
    }

    private func getSize(from photos: [Photo]) -> Int {
        guard let managedObjectContext = photos.first?.moc else {
            return 0
        }

        return managedObjectContext.performAndWait {
            return photos.flatMap { $0.children + [$0] }.map { $0.size }.reduce(0, +)
        }
    }

    func cancel() {
        subscription?.cancel()
        subscription = nil
    }
}
