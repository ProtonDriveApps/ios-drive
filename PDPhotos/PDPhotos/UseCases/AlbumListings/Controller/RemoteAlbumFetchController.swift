// Copyright (c) 2025 Proton AG
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
import PDCore
import PDCoreIOS

protocol RemoteAlbumFetchControllerProtocol {
    func execute(input: ListAlbumsInput)

    var errorPublisher: AnyPublisher<Error, Never> { get }
    var finishPublisher: AnyPublisher<Void, Never> { get }
}

final class RemoteAlbumFetchController: RemoteAlbumFetchControllerProtocol {
    private let dependencies: Dependencies
    private let errorSubject = PassthroughSubject<Error, Never>()
    private let finishSubject = PassthroughSubject<Void, Never>()
    var errorPublisher: AnyPublisher<Error, Never> {
        errorSubject.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }
    var finishPublisher: AnyPublisher<Void, Never> {
        finishSubject.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func execute(input: ListAlbumsInput) {
        Task {
            do {
                let albums = try await dependencies.interactor.execute(input: input)
                try await retrieveSharedWithMe(albums: albums)
                try await dependencies.storeAlbumListingsRepository.store(listings: albums)
                finishSubject.send(())
            } catch {
                Log.error(error: error, domain: .albums)
                errorSubject.send(error)
            }
        }
    }

    private func retrieveSharedWithMe(albums: [RemoteAlbumListing]) async throws {
        let links = albums
            .filter { $0.volumeID != dependencies.photoVolumeID }
            .compactMap { listing -> SharedWithMeLink? in
                guard let shareID = listing.shareID else { return nil }
                return .init(linkId: listing.linkID, shareId: shareID, volumeId: listing.volumeID)
            }
        
        guard !links.isEmpty else {
            return
        }

        // Repeated calls will bootstrap repeatedly. This is redundant, we should filter out whatever is already
        // in DB.
        try await dependencies.starter.bootstrap(remoteLinks: links)
        try await dependencies.retriever.retrieve(links: links)
    }
}

extension RemoteAlbumFetchController {
    struct Dependencies {
        let interactor: ListAllAlbumInteractorProtocol
        let photoVolumeID: String
        let retriever: SharedLinkRetriever
        let starter: SharedWithMeAlbumStarterProtocol
        let storeAlbumListingsRepository: StoreAlbumListingsRepository
    }
}
