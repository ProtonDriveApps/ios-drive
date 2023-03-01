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

import Foundation

final class ContentCreatorOperationFactory: OperationIterator {
    let draft: FileDraft
    let progress: Progress
    let contentCreator: CloudContentCreator
    let onError: OnError

    private var isFirstTime = true
    private let estimatedUnitsOfWork: UnitOfWork = 2

    init(draft: FileDraft, progress: Progress, contentCreator: CloudContentCreator, onError: @escaping OnError) {
        self.draft = draft
        self.progress = progress
        self.contentCreator = contentCreator
        self.onError = onError
        progress.modifyTotalUnitsOfWork(by: estimatedUnitsOfWork)
    }

    func next() -> Operation? {
        guard isFirstTime else { return nil }
        isFirstTime = false

        let operation = ContentsCreatorOperation(
            draft: draft,
            contentCreator: contentCreator,
            onError: onError
        )
        progress.addChild(operation.progress, pending: estimatedUnitsOfWork)
        return operation
    }
}
