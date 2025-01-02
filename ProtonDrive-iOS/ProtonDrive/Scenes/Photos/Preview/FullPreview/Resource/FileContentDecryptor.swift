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
        let url = try decryptedURL(from: file)
        // Verify decrypted file is usable
        try await validator.validate(file: file, url: url)
        let id = try identifier(of: file)
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
    
    private func decryptedURL(from file: FileType) throws -> URL {
        guard let moc = file.moc else { throw File.noMOC() }
        
        return try moc.performAndWait {
            guard let revision = file.activeRevision else {
                throw file.invalidState("Uploaded file should have an active revision")
            }

            return try revision.decryptFile()
        }
    }
    
    private func identifier(of file: FileType) throws -> NodeIdentifier {
        guard let moc = file.moc else { throw File.noMOC() }
        return moc.performAndWait {
            file.identifier
        }
    }
}
