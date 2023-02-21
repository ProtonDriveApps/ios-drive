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

public enum RefreshMode {  // request all pages with children when opening the Folder screen, request per-page, or rely on events completely
    case fetchAllPages, fetchPageByRequest, events
}

public enum Constants {
    public static let runningInExtension = Bundle.main.bundlePath.hasSuffix(".appex")
    static let developerGroup = "2SB5Z68H26."
    static let appGroup = "group.ch.protonmail.protondrive"
    public static let humanVerificationSupportURL = URL(string: "https://protonmail.ch")!
    
    // MARK: - Pagination - depends on BE capabilities
    public static let childrenRefreshStrategy: RefreshMode = .events
    
    public static let pageSizeForRefreshes: Int = 150      // number of node children per page when opening the Folder screen
    
    public static let maxBlockSize: Int = 4 * 1024 * 1024   // block size convenient for cloud (storage restrictions)
    public static let maxBlockChunkSize: Int = 96 * 1024   // chunk size during block encryption/decryption, convenient for client (memory restrictions)

    // MARK: - Thumbnails
    public static let thumbnailMaxWeight: Int = 60 * 1024
    public static let thumbnailMaxLength: Int = 512

    // MARK: - ShareURL
    public static let maxAccesses = 0
    public static let minSharedLinkRandomPasswordSize = 12
    public static let maxSharedLinkPasswordLength = 62
}
