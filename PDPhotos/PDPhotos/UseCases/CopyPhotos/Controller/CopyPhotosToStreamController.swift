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
import PDCore

protocol CopyPhotosToStreamControllerProtocol {
    var isCopying: AnyPublisher<Bool, Never> { get }

    func execute(parameters: CopyPhotoParameters)
}

final class CopyPhotosToStreamController: CopyPhotosToStreamControllerProtocol {
    private let copySubject: PassthroughSubject<Bool, Never> = .init()
    private let dependencies: Dependencies
    var isCopying: AnyPublisher<Bool, Never> { copySubject.eraseToAnyPublisher() }

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func execute(parameters: CopyPhotoParameters) {
        copySubject.send(true)
        Task {
            await asyncExecute(parameters: parameters)
        }
    }

    func asyncExecute(parameters: CopyPhotoParameters) async {
        do {
            let primaryIds = try await getPrimaryIds(with: parameters)
            let targetParentId = try dependencies.rootFolderIdRepository.getId()
            let copyParameters = CopyPhotosInteractor.Parameters(
                primaryIds: primaryIds,
                targetParentId: targetParentId,
                copyToPhotoRoot: true
            )
            let output = try await copy(with: copyParameters)
            await MainActor.run { [output] in
                dependencies.eventsSystemManager.forcePolling(volumeIDs: [targetParentId.volumeID])
                dependencies.copyMessageHandler.handle(output: output)
            }
        } catch {
            dependencies.userMessageHandler.handleError(PlainMessageError(error.localizedDescription))
        }
        await MainActor.run {
            copySubject.send(false)
        }
    }

    private func getPrimaryIds(with parameters: CopyPhotoParameters) async throws -> Set<AnyVolumeIdentifier> {
        switch parameters {
        case let .ids(primaryIds):
            return primaryIds
        case let .albumChildren(albumId):
            let listings = try await dependencies.albumChildrenInteractor.fetchAllChildren(albumId: albumId)
            return Set(listings.map(\.primary))
        }
    }

    private func copy(with parameters: CopyPhotosInteractor.Parameters) async throws -> CopyPhotosOutput {
        guard !parameters.primaryIds.isEmpty else {
            return CopyPhotosOutput(duplicatesCount: 0, initialCount: 0, targetParentId: parameters.targetParentId, result: .allSuccess([]))
        }

        return try await dependencies.copyPhotosInteractor.execute(parameters: parameters)
    }
}

extension CopyPhotosToStreamController {
    struct Dependencies {
        let copyMessageHandler: CopyPhotosMessageHandlerProtocol
        let copyPhotosInteractor: CopyPhotosInteractorProtocol
        let rootFolderIdRepository: PhotoVolumeRootFolderIdRepositoryProtocol
        let albumChildrenInteractor: AlbumAllChildrenInteractorProtocol
        let eventsSystemManager: EventsSystemManager
        let userMessageHandler: UserMessageHandlerProtocol
    }
}

enum CopyPhotoParameters {
    case ids(primaryIds: Set<AnyVolumeIdentifier>)
    case albumChildren(albumId: AnyVolumeIdentifier)
}
