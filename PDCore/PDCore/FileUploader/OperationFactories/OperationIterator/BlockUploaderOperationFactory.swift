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

import PDClient

final class BlockUploaderOperationFactory: OperationIterator {
    typealias BlockUploaderFactory = (FullUploadableBlock, Progress) -> URLSessionContentUploader

    private let draft: FileDraft
    private let progress: Progress
    private let uploader: BlockUploaderFactory
    private let onError: OnError

    let estimatedUnitsOfWork: UnitOfWork = 4
    private var isFirstTime = true
    private var blocks: ArraySlice<FullUploadableBlock> = []

    init(
        draft: FileDraft,
        progress: Progress,
        uploader: @escaping BlockUploaderFactory,
        onError: @escaping OnError
    ) {
        self.draft = draft
        self.progress = progress
        self.uploader = uploader
        self.onError = onError
        progress.modifyTotalUnitsOfWork(by: draft.numberOfBlocks * 4)
    }

    func next() -> Operation? {

        if isFirstTime {
            isFirstTime = false

            do {
                self.blocks = ArraySlice(try draft.getFullUploadableBlocks())
            } catch {
                onError(error)
                return NonFinishingOperation()
            }
        }

        guard let nextBlock = blocks.popFirst() else { return nil }

        var operation: Operation
        if nextBlock.uploadable.isUploaded {
            let finishingOperation = ImmediatelyFinishingOperation()
            operation = finishingOperation

            progress.addChild(finishingOperation.progress, pending: estimatedUnitsOfWork)

        } else {
            let progressTracker = Progress(unitsOfWork: 1)
            let uploader = uploader(nextBlock, progressTracker)

            let urlSession = URLSession(configuration: .ephemeral, delegate: uploader, delegateQueue: nil)
            uploader.session = urlSession

            operation = BlockUploaderOperation(
                draft: draft,
                progressTracker: progressTracker,
                blockIndex: nextBlock.uploadable.index,
                contentUploader: uploader,
                onError: onError
            )

            progress.addChild(progressTracker, pending: estimatedUnitsOfWork)
        }

        return operation
    }

}
