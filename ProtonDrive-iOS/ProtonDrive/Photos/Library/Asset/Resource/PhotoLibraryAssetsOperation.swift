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
import PDCore

typealias PhotoAssetCompoundsResult = Result<[PhotoAssetCompound], Error>
typealias PhotoAssetResultBlock = (PhotoAssetCompoundsResult) -> Void

final class PhotoLibraryAssetsOperation: AsynchronousOperation {
    private let resource: PhotoLibraryAssetsResource
    private let identifier: PhotoIdentifier
    private let completion: PhotoAssetResultBlock

    init(resource: PhotoLibraryAssetsResource, identifier: PhotoIdentifier, completion: @escaping PhotoAssetResultBlock) {
        self.resource = resource
        self.identifier = identifier
        self.completion = completion
    }

    override func main() {
        guard !isCancelled else {
            return
        }

        Task {
            await execute()
        }
    }

    private func execute() async {
        do {
            let asset = try await resource.execute(with: identifier)
            await finish(with: .success(asset))
        } catch {
            await finish(with: .failure(error))
        }
    }

    @MainActor
    private func finish(with result: Result<[PhotoAssetCompound], Error>) {
        completion(result)
        state = .finished
    }
}
