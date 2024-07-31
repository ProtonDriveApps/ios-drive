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

import Combine
import Foundation
import PDCore

struct PhotosDiagnostics: Equatable {
    let dumpUrls: [URL]
    let diffUrls: [URL]
    let libraryStorageDifferrences: TreeDifferences
    let storageCloudDifferences: TreeDifferences
    let libraryCloudDifferences: TreeDifferences
}

enum PhotosDiagnosticsState: Equatable {
    case library
    case database
    case cloud
    case conflicts
    case storing
    case diagnostics(PhotosDiagnostics)
}

final class PhotosDiagnosticsInteractor: ThrowingAsynchronousStateInteractor {
    private let libraryRepository: TreeRepository
    private let databaseRepository: TreeRepository
    private let cloudRepository: TreeRepository
    private let dumpInteractor: TreeDumpInteractor
    private let dumpStorageResource: PhotosDumpStorageResource
    private let diffStorageResource: PhotosDiffStorageResource
    private let differencesStrategy: DiagnosticsTreeDifferencesStrategy
    private let changeToStringConvertor: ChangeToStringConvertor
    private let subject = PassthroughSubject<Result<PhotosDiagnosticsState, Error>, Never>()

    var state: AnyPublisher<Result<PhotosDiagnosticsState, Error>, Never> {
        subject.eraseToAnyPublisher()
    }

    init(libraryRepository: TreeRepository, databaseRepository: TreeRepository, cloudRepository: TreeRepository, dumpInteractor: TreeDumpInteractor, dumpStorageResource: PhotosDumpStorageResource, diffStorageResource: PhotosDiffStorageResource, differencesStrategy: DiagnosticsTreeDifferencesStrategy, changeToStringConvertor: ChangeToStringConvertor) {
        self.libraryRepository = libraryRepository
        self.databaseRepository = databaseRepository
        self.cloudRepository = cloudRepository
        self.dumpInteractor = dumpInteractor
        self.dumpStorageResource = dumpStorageResource
        self.diffStorageResource = diffStorageResource
        self.differencesStrategy = differencesStrategy
        self.changeToStringConvertor = changeToStringConvertor
    }

    func execute() async throws {
        do {
            let libraryTree = await executeDump(state: .library, repository: libraryRepository)
            let databaseTree = await executeDump(state: .database, repository: databaseRepository)
            let cloudTree = await executeDump(state: .cloud, repository: cloudRepository)
            set(state: .storing)
            let libraryDump = try await dumpInteractor.dump(tree: libraryTree)
            let databaseDump = try await dumpInteractor.dump(tree: databaseTree)
            let cloudDump = try await dumpInteractor.dump(tree: cloudTree)
            let dumpUrls = try dumpStorageResource.store(libraryDump: libraryDump, databaseDump: databaseDump, cloudDump: cloudDump)
            set(state: .conflicts)
            let libraryStorageDifferrences = differencesStrategy.compare(lhs: libraryTree, rhs: databaseTree)
            let storageCloudDifferences = differencesStrategy.compare(lhs: databaseTree, rhs: cloudTree)
            let libraryCloudDifferences = differencesStrategy.compare(lhs: libraryTree, rhs: cloudTree)
            let diffUrls = try diffStorageResource.store(
                libraryStorageDiff: changeToStringConvertor.convert(libraryStorageDifferrences.changes),
                storageCloudDiff: changeToStringConvertor.convert(storageCloudDifferences.changes),
                libraryCloudDiff: changeToStringConvertor.convert(libraryCloudDifferences.changes)
            )
            let diagnostics = PhotosDiagnostics(
                dumpUrls: dumpUrls,
                diffUrls: diffUrls,
                libraryStorageDifferrences: libraryStorageDifferrences,
                storageCloudDifferences: storageCloudDifferences,
                libraryCloudDifferences: libraryCloudDifferences
            )
            set(state: .diagnostics(diagnostics))
        } catch {
            subject.send(.failure(error))
        }
    }

    private func executeDump(state: PhotosDiagnosticsState, repository: TreeRepository) async -> Tree {
        do {
            set(state: state)
            return try await repository.get()
        } catch {
            Log.error("Failed to dump: \(error.localizedDescription)", domain: .diagnostics)
            return Tree(root: Tree.Node(nodeTitle: "Error: \(error.localizedDescription)"))
        }
    }

    private func set(state: PhotosDiagnosticsState) {
        subject.send(.success(state))
    }
}
