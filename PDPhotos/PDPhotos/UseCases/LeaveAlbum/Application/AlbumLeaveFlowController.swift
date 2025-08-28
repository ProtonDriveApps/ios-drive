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
import Foundation
import PDCore
import PDClient

protocol AlbumLeaveFlowControllerProtocol {
    var leavingPublisher: AnyPublisher<Bool, Never> { get }

    func presentAlert(parameters: AlbumLeaveParameters)
}

final class AlbumLeaveFlowController: AlbumLeaveFlowControllerProtocol {
    private let dependencies: Dependencies
    private let isLeaving = CurrentValueSubject<Bool, Never>(false)
    var leavingPublisher: AnyPublisher<Bool, Never> {
        isLeaving.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func presentAlert(parameters: AlbumLeaveParameters) {
        let title = albumTitle(album: parameters.album)
        dependencies.coordinator.presentLeaveAlbumAlert(
            albumName: title,
            leaveWithoutSaving: { [weak self] in
                self?.leaveAlbumWithoutSaving(album: parameters.album, shouldCopyPhotos: false)
            },
            saveAndLeave: makeSaveAndLeaveBlock(parameters: parameters)
        )
    }

    private func makeSaveAndLeaveBlock(parameters: AlbumLeaveParameters) -> (() -> Void)? {
        guard parameters.album.photoCount < 100 else {
            return nil
        }
        return { [weak self] in
            self?.leaveAlbumWithoutSaving(album: parameters.album, shouldCopyPhotos: true)
        }
    }
}

extension AlbumLeaveFlowController {
    private func albumTitle(album: Album) -> String {
        album.clearName ?? "Album"
    }

    private func leaveAlbumWithoutSaving(album: Album, shouldCopyPhotos: Bool) {
        guard let memberID = album.memberID, let shareID = album.shareID else { return }
        let context = dependencies.context
        isLeaving.send(true)
        Task {
            do {
                var copyOutput: CopyPhotosOutput?
                if shouldCopyPhotos {
                    Log.info("Going to copy all photos before leaving the album.", domain: .albums)
                    copyOutput = try await executeCopy(identifier: album.identifier)
                }

                Log.info("Going leave album \(album.identifier).", domain: .albums)
                try await dependencies.client.removeMember(shareID: shareID, memberID: memberID)
                try await context.perform {
                    if let album = CoreDataAlbum.fetch(identifier: album.identifier, in: context) {
                        context.delete(album)
                    }
                    if let share = Share.fetch(id: shareID, in: context) {
                        context.delete(share)
                    }
                    try context.saveOrRollback()
                }
                await MainActor.run { [copyOutput] in
                    dependencies.coordinator.pop()
                    if let copyOutput {
                        dependencies.copyMessageHandler.handle(output: copyOutput)
                        dependencies.eventsSystemManager.forcePolling(volumeIDs: [copyOutput.targetParentId.volumeID])
                    }
                }
            } catch {
                dependencies.userMessageHandler.handleError(PlainMessageError(error.localizedDescription))
                isLeaving.send(false)
            }
        }
    }

    private func executeCopy(identifier: AnyVolumeIdentifier) async throws -> CopyPhotosOutput {
        let input = AlbumCopyAllPhotosInput(albumId: identifier)
        let output = try await dependencies.copyAllInteractor.execute(with: input)
        switch output.result {
        case let .failure(error):
            if let error {
                throw error
            }
        case let .partialSuccess(_, error):
            if let error {
                throw error
            }
        default:
            break
        }
        return output
    }
}

extension AlbumLeaveFlowController {
    struct Dependencies {
        let context: NSManagedObjectContext
        let coordinator: AlbumDetailCoordinatorProtocol
        let client: ShareMemberAPIClient
        let eventsSystemManager: EventsSystemManager
        let userMessageHandler: UserMessageHandlerProtocol
        let copyAllInteractor: AlbumCopyAllPhotosInteractorProtocol
        let copyMessageHandler: CopyPhotosMessageHandlerProtocol
    }
}

struct AlbumLeaveParameters {
    let album: Album
}
