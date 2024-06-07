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

public struct UploadingFileIdentifier {
    public let nodeId: String
    public let shareId: String
    public let revisionId: String

    public var identifier: NodeIdentifier {
        NodeIdentifier(nodeId, shareId)
    }

    public init(nodeId: String, shareId: String, revisionId: String) {
        self.nodeId = nodeId
        self.shareId = shareId
        self.revisionId = revisionId
    }
}

public struct VerifiableBlock {
    public let identifier: UploadingFileIdentifier
    public let index: Int

    public init(identifier: UploadingFileIdentifier, index: Int) {
        self.identifier = identifier
        self.index = index
    }
}

public enum UploadVerifierError: Error {
    case uninitialized
    case invalidResponse
    case missingFile
    case missingRevision
    case missingBlock
    case missingBlockContent
}

public typealias BlockToken = String

public protocol UploadVerifier {
    func verify(block: VerifiableBlock) async throws -> BlockToken
}
