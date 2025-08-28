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

import PDCore

protocol AddPhotosToAlbumMessageHandlerProtocol {
    func handle(output: AddPhotosToAlbumOutput)
    func handle(error: Error)
}

final class AddPhotosToAlbumMessageHandler: AddPhotosToAlbumMessageHandlerProtocol {
    private let messageHandler: UserMessageHandlerProtocol
    private let operationMessageHandler: PhotosMoveOperationMessageHandlerProtocol
    private let copyMessageHandler: CopyPhotosMessageHandlerProtocol

    init(messageHandler: UserMessageHandlerProtocol, operationMessageHandler: PhotosMoveOperationMessageHandlerProtocol, copyMessageHandler: CopyPhotosMessageHandlerProtocol) {
        self.messageHandler = messageHandler
        self.operationMessageHandler = operationMessageHandler
        self.copyMessageHandler = copyMessageHandler
    }

    func handle(output: AddPhotosToAlbumOutput) {
        switch output.result {
        case let .added(result):
            operationMessageHandler.showAddPhotosBanner(for: result)
        case let .copied(result):
            copyMessageHandler.handle(output: result)
        }
    }

    func handle(error: Error) {
        messageHandler.handleError(PlainMessageError(error.localizedDescription))
    }
}
