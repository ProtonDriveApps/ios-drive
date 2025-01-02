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

import PDCore

final class PhotosDuplicatesCheckInteractor: AsynchronousExecution {
    private let context: PhotosProcessingContext
    private let interactor: PhotoAssetCompoundsConflictInteractor
    private let skippableCache: PhotosSkippableCache
    private let measurementRepository: DurationMeasurementRepository

    init(context: PhotosProcessingContext, interactor: PhotoAssetCompoundsConflictInteractor, skippableCache: PhotosSkippableCache, measurementRepository: DurationMeasurementRepository) {
        self.context = context
        self.interactor = interactor
        self.skippableCache = skippableCache
        self.measurementRepository = measurementRepository
    }

    func execute() async {
        Log.info("3️⃣ \(Self.self): executing", domain: .photosProcessing)
        let compounds = context.createdCompounds
        guard !compounds.isEmpty else { return }
        measurementRepository.start()
        do {
            let result = try await interactor.execute(with: compounds)
            context.completeCompoundsValidation(result: result)
            context.duplicatedCompoundIdentifiers.forEach { identifier in
                let compounds = context.fetchDuplicatedCompounds(by: identifier)
                let skippableFiles = compounds.reduce(0, { $0 + $1.secondary.count + 1 })
                skippableCache.markAsSkippable(identifier, skippableFiles: skippableFiles)
            }
        } catch {
            // TODO:DRVIOS-3072 if error happens this becomes an infinite loop
            context.failValidation(compounds: compounds, error: error)
        }
        measurementRepository.stop()
    }
}
