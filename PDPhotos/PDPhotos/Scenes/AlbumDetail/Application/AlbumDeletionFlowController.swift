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

import CoreData
import Combine
import PDCore
import PDCoreIOS
import ProtonCoreNetworking

protocol AlbumDeletionFlowControllerProtocol {
    var deletingPublisher: AnyPublisher<Bool, Never> { get }

    func presentAlert(parameters: AlbumDeletionFlowController.Parameters) async throws
}

final class AlbumDeletionFlowController: AlbumDeletionFlowControllerProtocol {
    private let dependencies: Dependencies
    private let isDeleting = CurrentValueSubject<Bool, Never>(false)
    private var failedDueToLackingMetadata = false
    var deletingPublisher: AnyPublisher<Bool, Never> {
        isDeleting
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func presentAlert(parameters: Parameters) async throws {
        failedDueToLackingMetadata = false
        let children = try await dependencies.filterPolicy.filter(photoIdentifiers: parameters.photoIdentifiers)
        if children.isEmpty {
            await presentDeleteAlert(album: parameters.album)
        } else {
            await presentSaveWarning(children: children, album: parameters.album)
        }
    }
}

// MARK: - Present alert related
extension AlbumDeletionFlowController {
    private func presentDeleteAlert(album: Album) async {
        await MainActor.run {
            let title = albumTitle(album: album)
            dependencies.coordinator.presentDeleteAlbumAlert(albumName: title) { [weak self] in
                self?.delete(album: album, option: .softDelete)
            }
        }
    }

    private func presentSaveWarning(
        children: [AnyVolumeIdentifier],
        album: Album
    ) async {
        await MainActor.run {
            let title = albumTitle(album: album)
            dependencies.coordinator.presentDeleteAlbumAndMovePhotosAlert(
                albumName: title,
                moveAndRemove: { [weak self] in
                    self?.delete(album: album, option: .moveAndSoftDelete(children: children))
                },
                deleteWithoutSaving: { [weak self] in
                    self?.delete(album: album, option: .forceDelete)
                }
            )
        }
    }

    private func albumTitle(album: Album) -> String {
        album.clearName ?? "Album"
    }
}

// MARK: - Delete album related
extension AlbumDeletionFlowController {
    private func delete(album: Album, option: Option) {
        isDeleting.send(true)
        Task {
            do {
                try await doDeleteRequest(option: option, albumIdentifier: album.identifier)
                await handleDeleteAlbumSucceeded(volumeID: album.identifier.volumeID)
            } catch {
                await handleDeleteAlbumFailed(error: error, option: option, album: album)
            }
        }
    }

    private func doDeleteRequest(option: Option, albumIdentifier: AnyVolumeIdentifier) async throws {
        Log.info("Prepare to delete album, option: \(option)", domain: .albums)
        let forceDeleteAlbum: Bool
        var idsNeedToBeMoved: Set<AnyVolumeIdentifier> = []
        switch option {
        case .forceDelete:
            forceDeleteAlbum = true
        case .softDelete:
            forceDeleteAlbum = false
        case let .fetchRemoteAndMoveAndSoftDelete(children):
            // All ids need to be fetched, then we can delete
            forceDeleteAlbum = false
            idsNeedToBeMoved = try await dependencies.fetchInteractor.execute(identifier: albumIdentifier, children: children)
        case let .moveAndSoftDelete(children):
            // We may not have all items locally.
            // In case we do, the move & deletion will succeed
            // In case we don't, we'll receive an error and will retry with `fetchRemoteAndMoveAndForceDelete`
            forceDeleteAlbum = false
            idsNeedToBeMoved = Set(children)
        }

        Log.info("Execute delete album, forceDeleteAlbum: \(forceDeleteAlbum), photos to be moved: \(idsNeedToBeMoved.count)", domain: .albums)
        try await dependencies.deleteAlbumController.execute(
            parameters: .init(
                albumID: albumIdentifier,
                deleteAlbumPhotos: forceDeleteAlbum,
                photoIDsNeedToBeMoved: idsNeedToBeMoved
            )
        )
    }

    private func handleDeleteAlbumSucceeded(volumeID: String) async {
        await MainActor.run {
            dependencies.eventsSystemManager.forcePolling(volumeIDs: [volumeID])
            dependencies.coordinator.pop()
            isDeleting.send(false)
        }
    }

    private func handleDeleteAlbumFailed(error: Error, option: Option, album: Album) async {
        guard let deleteAlbumError = error as? DeleteAlbumErrors else {
            handleUnknownError(error: error)
            return
        }

        switch deleteAlbumError {
        case .photoNotFound:
            if failedDueToLackingMetadata {
                handleUnknownError(error: error)
            } else {
                // Some photos don't have metadata in local
                // Fetch remote photos and delete again
                delete(album: album, option: .fetchRemoteAndMoveAndSoftDelete(children: []))
                failedDueToLackingMetadata = true
            }
        case let .containsDirectChildren(linkIds):
            // The album has direct children that haven't been moved
            let childrenIdentifiers = linkIds.map { AnyVolumeIdentifier(id: $0, volumeID: album.identifier.volumeID) }
            switch option {
            case .softDelete:
                // Has remote photos
                // Need to check user's intentions and potentially retry with the full children list
                await presentSaveWarning(children: childrenIdentifiers, album: album)
                isDeleting.send(false)
            case .forceDelete:
                assert(false, "Force delete shouldn't have this error")
                handleUnknownError(error: error)
            case .fetchRemoteAndMoveAndSoftDelete:
                assert(false, "Fetch and delete shouldn't have this error")
                handleUnknownError(error: error)
            case .moveAndSoftDelete:
                // Not all children were moved, let's try again with the remote linkIds
                delete(album: album, option: .fetchRemoteAndMoveAndSoftDelete(children: childrenIdentifiers))
            }
        }
    }

    private func handleUnknownError(error: Error) {
        Log.error(error: error, domain: .albums)
        dependencies.userMessageHandler.handleError(PlainMessageError(error.localizedDescription))
        isDeleting.send(false)
    }
}

extension AlbumDeletionFlowController {
    struct Dependencies {
        let coordinator: AlbumDetailCoordinatorProtocol
        let deleteAlbumController: DeleteAlbumControllerProtocol
        let eventsSystemManager: EventsSystemManager
        let fetchInteractor: DirectChildrenInAlbumFetchInteractorProtocol
        let filterPolicy: AlbumDirectChildrenFilterPolicyProtocol
        let userMessageHandler: UserMessageHandlerProtocol

        init(
            coordinator: AlbumDetailCoordinatorProtocol,
            deleteAlbumController: DeleteAlbumControllerProtocol,
            eventsSystemManager: EventsSystemManager,
            fetchInteractor: DirectChildrenInAlbumFetchInteractorProtocol,
            filterPolicy: AlbumDirectChildrenFilterPolicyProtocol,
            userMessageHandler: UserMessageHandlerProtocol = UserMessageHandler()
        ) {
            self.coordinator = coordinator
            self.deleteAlbumController = deleteAlbumController
            self.eventsSystemManager = eventsSystemManager
            self.fetchInteractor = fetchInteractor
            self.filterPolicy = filterPolicy
            self.userMessageHandler = userMessageHandler
        }
    }

    struct Parameters {
        /// Local photo identifier of the album
        let photoIdentifiers: [AnyVolumeIdentifier]
        let album: Album
    }

    enum Option {
        /// Force delete the album even if it has direct children
        case forceDelete
        /// Try soft delete. Will need to retry when there are remote children
        case softDelete
        /// There are remote items that need to be fetched. We need to fetch, then move them and then delete.
        /// BE can give us additional children (like trashed ones), so we need to include them too.
        case fetchRemoteAndMoveAndSoftDelete(children: [AnyVolumeIdentifier])
        /// Move and then soft delete items that we know of.
        case moveAndSoftDelete(children: [AnyVolumeIdentifier])
    }
}
