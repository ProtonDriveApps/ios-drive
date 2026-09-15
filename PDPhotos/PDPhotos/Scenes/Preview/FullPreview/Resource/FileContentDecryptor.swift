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

/// Decrypt downloaded file and verify the file is usable
/// Video is playable, image is readable
protocol FileContentDecryptor<FileType> {
    associatedtype FileType
    
    func loadAndValidateDecryptedURL(from file: FileType) async throws -> (NodeIdentifier, URL)
    func loadAndValidateDecryptedURL(from files: [FileType]) async throws -> [NodeIdentifier: URL]
}

final class RemoteFileContentDecryptor<T: File>: FileContentDecryptor {
    typealias FileType = T

    private let validator: FileURLValidationResource

    init(validator: FileURLValidationResource) {
        self.validator = validator
    }

    func loadAndValidateDecryptedURL(from file: FileType) async throws -> (NodeIdentifier, URL) {
        let url = try await decryptedURL(from: file)
        // Verify decrypted file is usable
        try await validator.validate(file: file, url: url)
        let id = file.volumeBasedIdentifier
        return (id, url)
    }

    func loadAndValidateDecryptedURL(from files: [FileType]) async throws -> [NodeIdentifier: URL] {
        try await withThrowingTaskGroup(of: (NodeIdentifier, URL).self) { [weak self] group in
            guard let self else { return [:] }
            for file in files {
                group.addTask { try await self.loadAndValidateDecryptedURL(from: file) }
            }
            var results: [NodeIdentifier: URL] = [:]
            for try await result in group {
                results[result.0] = result.1
            }
            return results
        }
    }

    private func decryptedURL(from file: FileType) async throws -> URL {
        if DecryptedFileManager.validatedDecryptedFilePath(identifier: file.identifier) == nil {
            try await DecryptedFileManager.decryptLegacyBlocksIfNeeded(file: file)
        }
        
        return try DecryptedFileManager.ensureHardLink(
            identifier: file.genericIdentifier,
            filename: file.decryptedName
        )
    }
}
