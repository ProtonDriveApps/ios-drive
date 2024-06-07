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

typealias DownloadingPhotoIds = Set<String>

protocol OfflineAvailableController {
    var inProgressIds: AnyPublisher<DownloadingPhotoIds, Never> { get }
    func toggle(ids: PhotoIdsSet)
}

final class UpdatingOfflineAvailableController: OfflineAvailableController {
    private let resource: OfflineAvailableResource
    private let subject = CurrentValueSubject<DownloadingPhotoIds, Never>([])
    private var relevantIds = DownloadingPhotoIds()
    private var cancellables = Set<AnyCancellable>()

    var inProgressIds: AnyPublisher<DownloadingPhotoIds, Never> {
        subject.removeDuplicates().eraseToAnyPublisher()
    }

    init(resource: OfflineAvailableResource) {
        self.resource = resource
        resource.inProgressIds
            .sink { [weak self] ids in
                guard let self else { return }
                let ids = ids.intersection(self.relevantIds)
                self.subject.send(ids)
            }
            .store(in: &cancellables)
    }

    func toggle(ids: PhotoIdsSet) {
        relevantIds.formUnion(ids.map(\.nodeID))
        resource.toggle(ids: ids)
    }
}
