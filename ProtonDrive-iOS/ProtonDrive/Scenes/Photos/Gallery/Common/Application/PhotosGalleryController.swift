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

protocol PhotosGalleryController {
    var sections: AnyPublisher<[PhotosSection], Never> { get }
}

final class LocalPhotosGalleryController: PhotosGalleryController {
    private let subject = CurrentValueSubject<[PhotosSection], Never>([])

    var sections: AnyPublisher<[PhotosSection], Never> {
        subject.eraseToAnyPublisher()
    }

    init() {
        // TODO: next MR. This is just debug
        subject.send([
            .init(month: Date(timeIntervalSinceReferenceDate: 0), photos: [
                .init(id: "1", thumbnailId: "", duration: 123),
                .init(id: "2", thumbnailId: "", duration: 3789),
                .init(id: "3", thumbnailId: "", duration: nil),
                .init(id: "4", thumbnailId: "", duration: nil),
            ])
        ])
    }
}
