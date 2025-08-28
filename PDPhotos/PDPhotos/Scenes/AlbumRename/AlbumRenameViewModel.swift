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
import PDCore
import PDCoreIOS

final class AlbumRenameViewModel: ObservableObject {
    @Published var isProcessing = false
    @Published var name: String
    private let dependencies: Dependencies
    private let parameters: Parameters
    var canBeSaved: Bool { !name.isEmpty }
    private var renameHandler: (Error?) -> Void
    private var isCalledAPI = false
    private var apiError: Error?

    init(dependencies: Dependencies, parameters: Parameters, renameHandler: @escaping (Error?) -> Void) {
        self.parameters = parameters
        self.name = parameters.albumName
        self.dependencies = dependencies
        self.renameHandler = renameHandler
    }

    func onDisappear() {
        guard isCalledAPI else { return }
        renameHandler(apiError)
    }

    func tapDone(dismissHandler: @escaping () -> Void) {
        isProcessing = true
        isCalledAPI = true
        Task {
            do {
                try await dependencies.interactor.execute(
                    parameters: .init(
                        albumID: parameters.albumID,
                        coverLinkID: nil,
                        newAlbumName: name,
                        originalHash: parameters.originalHash
                    )
                )
                await MainActor.run {
                    dismissHandler()
                }
            } catch {
                Log.error(error: error, domain: .albums)
                dependencies.userMessageHandler.handleError(PlainMessageError(error.localizedDescription))
                await MainActor.run {
                    isProcessing = false
                }
            }
        }
    }
}

extension AlbumRenameViewModel {
    struct Dependencies {
        let interactor: UpdateAlbumInteractorProtocol
        let userMessageHandler: UserMessageHandlerProtocol

        init(
            interactor: UpdateAlbumInteractorProtocol,
            userMessageHandler: UserMessageHandlerProtocol = UserMessageHandler()
        ) {
            self.interactor = interactor
            self.userMessageHandler = userMessageHandler
        }
    }

    struct Parameters {
        let albumID: AnyVolumeIdentifier
        let albumName: String
        let originalHash: String
    }
}
