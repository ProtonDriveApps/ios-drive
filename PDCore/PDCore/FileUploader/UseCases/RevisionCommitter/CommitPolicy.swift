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

enum CommitPolicy {
    private static var blocksUploadedWrongly: Int { 2000 }
    private static var invalidManifestSignature: Int { 2001 }
    
    private static var revisionAlreadyCommited: Int { 2511 }
    
    private static var storageQuotaExceeded: Int { 200002 }
    
    static let invalidRevision: Set<Int?> = [
        blocksUploadedWrongly,
        invalidManifestSignature
    ]
    
    static let quotaExceeded: Set<Int?> = [
        storageQuotaExceeded
    ]
    
    static let revisionAlreadyCommittedErrors: Set<Int?> = [
        revisionAlreadyCommited
    ]
}
