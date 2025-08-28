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
    public static var runningInExtension = Bundle.main.bundlePath.hasSuffix(".appex")
    /// Are we running in an environment where we need to be very cautious about our RAM usage.
    public static let runningInRAMContrainedProcess = {
        #if os(macOS)
        // On Mac, extensions have no constraints on RAM usage compared to any other process.
        false
        #else
        // On iOS, extensions are severly limited in their RAM usage. Total amount depends on OS version.
        runningInExtension
        #endif
    }()
    public static let keychainGroup = "2SB5Z68H26.group.ch.protonmail.protondrive"
    public static var appGroup: String {
        #if os(macOS)
        "2SB5Z68H26.ch.protonmail.protondrive"
        #else
        "group.ch.protonmail.protondrive"
        #endif
    }
    public static let humanVerificationSupportURL = URL(string: "https://protonmail.ch")!
    
    public static var clientVersion: String? = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String

    // MARK: - Pagination - depends on BE capabilities
    public static let childrenRefreshStrategy: RefreshMode = .events
    
    // The children page size. This number is used when:
    // * fetching the folder's children from API — this is the API page size
    // * enumerating the items in the FileProviderExtension — this is the size of one page that FP requests
    // * opening the Folder screen — as number of node children per page
    public static let pageSizeForChildrenFetchAndEnumeration: Int = 150

    // MARK: - FileUpload
    #if os(macOS)
    public static let maxCountOfConcurrentFileUploaderOperations = 16 // Highlevel limit of parallel file uploads
    /// How many files can be downloaded at once, includes everything from preflight requests to final decryption.
    /// Ideally, this value should match `NSExtensionFileProviderDownloadPipelineDepth` in the Info.plist
    public static let maxConcurrentInflightFileDownloads = 6
    /// How many blocks in an individual file can be downloaded at once.
    public static let maxConcurrentBlockDownloadsPerFile = 4
    public static let downloaderUsesSharedURLSession = false
    #else
    public static let maxCountOfConcurrentFileUploaderOperations = 5 // Highlevel limit of parallel file uploads
    /// How many files can be downloaded at once, includes everything from preflight requests to final decryption
    public static let maxConcurrentInflightFileDownloads = 3
    /// How many blocks in an individual file can be downloaded at once
    public static let maxConcurrentBlockDownloadsPerFile = 1
    public static let downloaderUsesSharedURLSession = false
    #endif
    public static let maxChildrenInFolder = 32_000 // a bit under BE's 2^15 - 1 limit
    // Encryption
    public static let maxBlockSize: Int = 4 * 1024 * 1024   // block size convenient for cloud (storage restrictions)
    public static let maxBlockChunkSize: Int = 64 * 1024   // chunk size during block encryption/decryption, convenient for client (memory restrictions)
    public static let thumbnailMaxWeight: Int = 60 * 1024
    public static let photoThumbnailMaxWeight: Int = 1024 * 1024
    public static let defaultThumbnailMaxSize = CGSize(width: 512, height: 512)
    public static let photoThumbnailMaxSize = CGSize(width: 1920, height: 1920)

    // Revision Upload
    public static let blocksPaginationPageSize = 50 // Maximum number of URLs requested per uploading a revision
    #if os(macOS)
    public static let maxConcurrentPageOperations = 50 // Maximum number of pages processed for uploading a revision, per revision
    public static let discreteMaxConcurrentContentUploadOperations = 50 // Maximum number of content operations (blocks + thumbnail) processed at the same time per page
    #else
    public static let maxConcurrentPageOperations = 1 // Maximum number of pages processed for uploading a revision, per revision
    public static let discreteMaxConcurrentContentUploadOperations = 15 // Maximum number of content operations (blocks + thumbnail) processed at the same time per page
    #endif
    public static let streamMaxConcurrentContentUploadOperations = 1 // Maximum number of content operations (blocks + thumbnail) processed at the same time per page in a streamed fashion

    // MARK: Photos upload
    public static let discreteMaxConcurrentContentUploadOperationsPhotos = 1 // Maximum number of content operations (blocks + thumbnail) processed at the same time per page
    public static let processingPhotoUploadsBatchSize = 10 // Max number of photos added to the uploader queue at once

    // MARK: - ShareURL
    public static let maxAccesses = 0
    public static let minSharedLinkRandomPasswordSize = 12
    public static let maxSharedLinkPasswordLength = 62

    // MARK: - Build type
    @available(*, deprecated, message: "Avoid using. Use injection to differentiate implementation in the top level target instead.")
    public static var buildType = BuildType.prod

    // MARK: - Custom metadata model (overrides current version)
    public static var metadataModelUnderDevelopment: String? {
        return nil
    }

    // MARK: - Build type features
    public static var buildFeatures: BuildFeatures = .default
}
