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
import CoreData
import Foundation

public final class FetchResultControllerObserverPhotosBootstrapRepository: PhotosBootstrapRepository {
    private let queue = DispatchQueue.global(qos: .background)

    private let observer: FetchedResultsControllerObserver<Share>

    public init(observer: FetchedResultsControllerObserver<Share>) {
        self.observer = observer
    }

    public var state: AnyPublisher<PhotosShareState, Never> {
        observer.getPublisher()
            .receive(on: queue)
            .map { [weak self] shares in
                self?.getShareState(from: shares) ?? .notFound
            }
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    private func getShareState(from shares: [Share]) -> PhotosShareState {
        observer.fetchedResultsController.managedObjectContext.performAndWait {
            guard !shares.isEmpty else {
                return .notFound
            }
            if shares.first?.volume?.type == .photo {
                return .photoVolume
            } else {
                return .legacyShare
            }
        }
    }
}
