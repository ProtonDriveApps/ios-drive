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

protocol CopyPhotosMessageHandlerProtocol {
    func handle(output: CopyPhotosOutput)
}

final class CopyPhotosMessageHandler: CopyPhotosMessageHandlerProtocol {
    private let messageHandler: PhotosMoveOperationMessageHandlerProtocol

    init(messageHandler: PhotosMoveOperationMessageHandlerProtocol) {
        self.messageHandler = messageHandler
    }

    func handle(output: CopyPhotosOutput) {
        switch output.result {
        case .allSuccess(let ids):
            let messengerResult = PhotosMoveOperationResult(failure: 0, success: ids.count, duplication: output.duplicatesCount, incomplete: 0)
            messageHandler.showAddPhotosBanner(for: messengerResult)
        case let .partialSuccess(ids, error):
            if let error {
                Log.error("Partially failed to copy photos to album", error: error, domain: .albums)
            }
            let failedItems = output.initialCount - ids.count
            let messengerResult = PhotosMoveOperationResult(failure: failedItems, success: ids.count, duplication: output.duplicatesCount, incomplete: 0)
            messageHandler.showAddPhotosBanner(for: messengerResult)
        case .failure(let error):
            if let error {
                Log.error("Failed to copy photos to album", error: error, domain: .albums)
            }
            let messengerResult = PhotosMoveOperationResult(failure: output.initialCount, success: 0, duplication: output.duplicatesCount, incomplete: 0)
            messageHandler.showAddPhotosBanner(for: messengerResult)
        }
    }
}
