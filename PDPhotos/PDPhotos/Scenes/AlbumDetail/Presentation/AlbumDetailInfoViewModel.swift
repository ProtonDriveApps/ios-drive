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

import Foundation
import Combine
import PDCore
import PDLocalization
import PDCoreIOS

final class AlbumDetailInfoViewModel: ObservableObject {
    let configuration: PhotosRootConfiguration
    private let dependencies: Dependencies
    private var album: Album?
    private var cancellables: Set<AnyCancellable> = []
    private var hasCheckedInvitation: Bool = false
    private var shouldOpenInvitation: Bool
    private var albumRole: Role = .viewer

    @Published private(set) var title: String = ""
    @Published private(set) var info: String = ""
    @Published var invitationList: [InvitationInfoWrapper] = []
    @Published var isSharingAvailable: Bool = false
    @Published var saveAllButton: String?
    @Published var isSaveAllLoading = false

    var canAddPhotos: Bool {
        switch albumRole {
        case .viewer:
            return false
        case .editor, .admin:
            return dependencies.featureFlagsController.hasCopy
        case .owner:
            return true
        }
    }

    init(configuration: PhotosRootConfiguration, dependencies: Dependencies, shouldOpenInvitation: Bool) {
        self.configuration = configuration
        self.dependencies = dependencies
        self.shouldOpenInvitation = shouldOpenInvitation
        subscribeToUpdate()
    }

    func tapAdd() {
        dependencies.addPhotoSelectionController.start(selectedID: [])
        dependencies.coordinator.openPhotoPicker(selectionController: dependencies.addPhotoSelectionController)
    }

    func tapShare() {
        guard let identifier = album?.identifier else { return }
        dependencies.coordinator.openSharingMemberConfiguration(
            identifier: identifier,
            invitationResultController: dependencies.invitationResultController
        )
    }

    func tapSaveAll() {
        guard let albumId = album?.identifier else {
            return
        }

        let parameters = CopyPhotoParameters.albumChildren(albumId: albumId)
        dependencies.copyToStreamController.execute(parameters: parameters)
    }

    private func subscribeToUpdate() {
        dependencies.albumRepository.updatePublisher
            .sink { [weak self] album in
                guard let self, let album else { return }
                self.handleUpdate(album: album)
            }
            .store(in: &cancellables)
        dependencies.inviteeListLoadController.publisher
            .sink { [weak self] result in
                switch result {
                case .success(let list):
                    self?.invitationList = list
                case .failure(let error):
                    self?.dependencies.userMessageHandler.handleError(PlainMessageError(error.localizedDescription))
                }
            }
            .store(in: &cancellables)
        dependencies.invitationResultController.updatePublisher
            .sink { [weak self] list in
                self?.invitationList = list
            }
            .store(in: &cancellables)
        dependencies.copyToStreamController.isCopying
            .assign(to: &$isSaveAllLoading)
    }

    private func handleUpdate(album: Album) {
        self.album = album
        title = album.clearName ?? ""
        let date = dependencies.dateFormatter.string(from: album.lastActivityTime)
        info = "\(date) • \(Localization.item_plural_type_with_num(num: album.photoCount))"
        albumRole = album.role
        isSharingAvailable = albumRole.canShare && dependencies.featureFlagsController.hasSharing

        if albumRole.canShare, let shareID = album.shareID, !hasCheckedInvitation {
            hasCheckedInvitation = true
            dependencies.inviteeListLoadController.execute(shareID: shareID)
        }

        if shouldOpenInvitation && isSharingAvailable {
            shouldOpenInvitation = false
            tapShare()
        }

        let canSaveAll = album.role != .owner && album.photoCount < 100
        saveAllButton = canSaveAll ? Localization.general_save_all : nil
    }
}

extension AlbumDetailInfoViewModel {
    struct Dependencies {
        let addPhotoSelectionController: PhotosSelectionController
        let albumRepository: AlbumRepositoryProtocol
        let coordinator: AlbumDetailCoordinatorProtocol
        let featureFlagsController: FeatureFlagsControllerProtocol
        let inviteeListLoadController: InviteeListLoadControllerProtocol
        let invitationResultController: InvitationResultControllerProtocol
        let userMessageHandler: UserMessageHandlerProtocol
        let copyToStreamController: CopyPhotosToStreamControllerProtocol

        let dateFormatter: DateFormatter = {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "dd MMM yyyy"
            return dateFormatter
        }()
    }
}
