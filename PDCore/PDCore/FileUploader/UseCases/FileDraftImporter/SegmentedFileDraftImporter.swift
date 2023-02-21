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

final class SegmentedFileDraftImporter: FileDraftImporter {
    static let batchSize = 20

    private let storage: FileStorage
    private let signersKitFactory: SignersKitFactoryProtocol

    init(storage: FileStorage, signersKitFactory: SignersKitFactoryProtocol) {
        self.storage = storage
        self.signersKitFactory = signersKitFactory
    }

    func `import`(files: [URL], to folder: Folder) throws -> FileImportOutcome {
        let batches = segmentIntoBatches(files)

        var outcome: [FileImportOutcome] = []

        guard !batches.isEmpty else { throw Error.emptyBatch }
        let signersKit = try signersKitFactory.make(forSigner: .main)

        for batch in batches {
            let processed = try storage.importFilesRepresentation(for: batch, parent: folder, signersKit: signersKit)
            outcome.append(processed)
        }

        let successful = outcome.reduce([]) { $0 + $1.success }
        let failed = outcome.reduce([]) { $0 + $1.failure }
        return FileImportOutcome(success: successful, failure: failed)
    }

    private func segmentIntoBatches(_ files: [URL]) -> [[URL]] {
        files.splitInGroups(of: Self.batchSize)
    }

    enum Error: Swift.Error {
        case emptyBatch
    }
}
