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

public final class RecursiveValidNameDiscoverer: ValidNameDiscoverer {
    public typealias FileName = String
    public typealias ParentHashKey = String
    public typealias Hasher = (FileName, ParentHashKey) throws -> String

    private let hashChecker: AvailableHashChecker
    private let hasher: Hasher
    private let step: Int

    public init(hashChecker: AvailableHashChecker, step: Int = 15, hasher: @escaping Hasher = Encryptor.hmac) {
        self.hashChecker = hashChecker
        self.hasher = hasher
        self.step = step
    }

    public func findNextAvailableName(for file: FileNameCheckerModel, completion: @escaping (Result<NameHashPair, Error>) -> Void) {
        findNextAvailableName(for: file, offset: 0, completion: completion)
    }

    public func findNextAvailableName(for file: FileNameCheckerModel) async throws -> NameHashPair {
        try await withCheckedThrowingContinuation { continuation in
            findNextAvailableName(for: file, offset: 0) { result in
                continuation.resume(with: result)
            }
        }
    }

    private func findNextAvailableName(for file: FileNameCheckerModel, offset: Int, completion: @escaping (Result<NameHashPair, Error>) -> Void) {
        assert(offset >= 0)
        let fileName = file.originalName.fileName
        let `extension` = file.originalName.fileExtension
        var possibleNamesHashPairs = [NameHashPair]()

        let lowerBound = offset + 1
        let upperBound = offset + step

        for iteration in lowerBound...upperBound {
            let newName = "\(fileName) (\(iteration))" + (`extension`.isEmpty ? "" : "." + `extension`)
            guard let newHash = try? hasher(newName, file.parentNodeHashKey) else { continue }
            possibleNamesHashPairs.append(NameHashPair(name: newName, hash: newHash))
        }

        hashChecker.checkAvailableHashes(among: possibleNamesHashPairs, onFolder: file.parent) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .failure(let error):
                completion(.failure(error))

            case .success(let approvedHashes) where approvedHashes.isEmpty:
                self.findNextAvailableName(for: file, offset: upperBound, completion: completion)

            case .success(let approvedHashes):
                let approvedPair = possibleNamesHashPairs.first { approvedHashes.contains($0.hash) }!
                completion(.success(approvedPair))
            }
        }
    }

}
