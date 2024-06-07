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

protocol FileHashResource {
    func getHash(at url: URL) throws -> Data
}

enum Sha1FileHashResourceError: Error {
    case missingSize
}

final class FileStreamHashResource: FileHashResource {
    private let digestBuilderFactory: () -> DigestBuilder // Needs to be a factory because every hash operation needs unique builder

    init(digestBuilderFactory: @escaping () -> DigestBuilder) {
        self.digestBuilderFactory = digestBuilderFactory
    }

    func getHash(at url: URL) throws -> Data {
        guard let totalSize = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int else {
            throw Sha1FileHashResourceError.missingSize
        }

        let fileHandle = try FileHandle(forReadingFrom: url)
        defer { try? fileHandle.close() }
        let digestBuilder = digestBuilderFactory()
        let bufferSize = PDCore.Constants.maxBlockSize

        var offset = 0
        while offset < totalSize {
            try autoreleasepool {
                try fileHandle.seek(toOffset: UInt64(offset))
                let size = offset + bufferSize > totalSize ? totalSize - offset : bufferSize
                let data = try fileHandle.read(upToCount: size) ?? Data()
                digestBuilder.add(data)
                offset += size
            }
        }

        return digestBuilder.getResult()
    }
}
