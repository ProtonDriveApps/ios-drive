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

import CoreData
import PDCore

final class PhotosCloudTreeRepository: TreeRepository {
    private let metadataRepository: PhotosDiagnosticsMetadataRepository
    private let mappingInteractor: PhotosDiagnosticsMappingInteractor

    init(metadataRepository: PhotosDiagnosticsMetadataRepository, mappingInteractor: PhotosDiagnosticsMappingInteractor) {
        self.metadataRepository = metadataRepository
        self.mappingInteractor = mappingInteractor
    }

    func get() async throws -> Tree {
        Log.debug("Fetching all photos from BE", domain: .diagnostics)
        let response = try await metadataRepository.load()
        Log.debug("Mapping BE photos to a tree structure", domain: .diagnostics)
        let nodes = try mappingInteractor.map(response: response)
        return Tree(root: Tree.Node(title: "root", descendants: nodes))
    }
}
