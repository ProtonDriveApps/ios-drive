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

final class MigratePhotoTagsUseCase: ThrowingAsynchronousWithoutDataInteractor {
    private let stateLoader: TagsMigrationStateLoader
    private let pager: PhotoTagMigrationPager
    private let analyzer: PhotoTagAnalyzer
    private let batchAssigner: PhotoTagBatchAssigner
    private let batchBackfiller: PhotoXAttrBatchBackfiller
    private let stateUpdater: PhotoTagsMigrationStateUpdater
    private let blocksDeleter: ProcessedPhotoBlockDeleter
    private let volumeID: String

    init(
        stateLoader: TagsMigrationStateLoader,
        pager: PhotoTagMigrationPager,
        analyzer: PhotoTagAnalyzer,
        batchAssigner: PhotoTagBatchAssigner,
        batchBackfiller: PhotoXAttrBatchBackfiller,
        stateUpdater: PhotoTagsMigrationStateUpdater,
        blocksDeleter: ProcessedPhotoBlockDeleter,
        volumeID: String
    ) {
        self.stateLoader = stateLoader
        self.pager = pager
        self.analyzer = analyzer
        self.batchAssigner = batchAssigner
        self.batchBackfiller = batchBackfiller
        self.stateUpdater = stateUpdater
        self.blocksDeleter = blocksDeleter
        self.volumeID = volumeID
    }

    func execute() async throws {
        // Keep track of the last item that was successfully processed across batches.
        var lastSuccessfullyProcessedItem: AnyVolumeIdentifier?

        // Step 1: Migration loop with eligibility check
        while !Task.isCancelled, let state = try await stateLoader.loadStateIfEligible(volumeID: volumeID) {

            if Task.isCancelled { return }

            // Fetch the next batch of photos starting from the last known anchor.
            let batch = try await pager.nextBatch(from: state.anchor)
            let identifiers = batch.map(\.identifier)

            if Task.isCancelled { return }

            // Check if the batch is empty, which signals the end of the migration.
            guard let lastItem = batch.last else {
                // Use the ID of the last successfully processed item, or fall back to the volume ID.
                // Mark the migration as finished in the backend.
                let lastID = lastSuccessfullyProcessedItem?.id ?? volumeID
                try await stateUpdater.markFinished(id: lastID)
                return
            }

            // Step 2: Analyze photos in this batch
            let analysisResult = try await analyzer.analyze(identifiers: identifiers)

            if Task.isCancelled { return }

            // Step 3: Batch update tag & xattr to backend
            try await batchUpdate(analysisResult: analysisResult)

            if Task.isCancelled { return }

            // Step 4: Mark migration progress in backend
            try await stateUpdater.updateAnchor(lastProcessedID: lastItem.identifier.id, lastProcessedCaptureTime: lastItem.captureTime)

            // After a successful update, store the identifier of the last processed item.
            lastSuccessfullyProcessedItem = identifiers.last

            // Step 5: Delete processed blocks
            // This operation is allowed to fail without stopping the entire migration.
            try? await blocksDeleter.deleteBlocks(for: identifiers)
        }
    }

    private func batchUpdate(analysisResult: [MigrationAnalyzeReport]) async throws {
        try await withThrowingTaskGroup(of: Void.self) { [weak self] group in
            group.addTask { [weak self] in
                guard let self else { return }
                let taggingContext: [AnyVolumeIdentifier: [PhotoTag]] = Dictionary(
                    uniqueKeysWithValues: analysisResult.compactMap { report in
                        if report.updatedTags.isEmpty { return nil }
                        return (report.identifier, report.updatedTags)
                    }
                )
                try await self.batchAssigner.assignTagsAndFavorites(for: taggingContext)
            }

            group.addTask { [weak self] in
                guard let self else { return }
                try await self.batchBackfiller.execute(reports: analysisResult)
            }

            try await group.waitForAll()
        }
    }
}
