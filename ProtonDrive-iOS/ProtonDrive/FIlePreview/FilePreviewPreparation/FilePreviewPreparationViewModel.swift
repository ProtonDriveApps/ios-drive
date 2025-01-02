// Copyright (c) 2024 Proton AG
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
import PDLocalization

final class FilePreviewPreparationViewModel {
    private let repository: FilePreviewRepository
    private let coordinator: FilePreviewPreparationCoordinatorProtocol
    private let errorHandler: UserMessageHandlerProtocol

    private var isCancelled = false

    init(
        repository: FilePreviewRepository,
        coordinator: FilePreviewPreparationCoordinatorProtocol,
        errorHandler: UserMessageHandlerProtocol
    ) {
        self.coordinator = coordinator
        self.errorHandler = errorHandler
        self.repository = repository
    }

    var title: String {
        Localization.general_decrypting
    }

    var cancelTitle: String {
        Localization.prepare_preview_cancel
    }

    func prepareFile() {
        Task {
            do {
                try await self.repository.loadFile()
                guard !isCancelled else { return }
                await coordinator.onFileDecrypted()
            } catch let error as LocalizedError {
                errorHandler.handleError(error)
            }
        }
    }

    func cancel() {
        isCancelled = true
        repository.cancel()
    }
}
