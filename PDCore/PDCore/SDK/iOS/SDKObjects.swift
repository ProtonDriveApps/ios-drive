// Copyright (c) 2026 Proton AG
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

public protocol SDKObjectsProtocol {
    var fileDownloader: SDKFileDownloaderProtocol { get }
    var fileUploader: SDKFileUploaderProtocol { get }
    var nodeOperationPerformer: SDKNodeOperationPerformer? { get }
    var photoDownloader: SDKFileDownloaderProtocol { get }
    var photoUploader: SDKFileUploaderProtocol { get }
    var revisionUploader: SDKRevisionUploaderProtocol { get }
    var thumbnailDownloader: SDKThumbnailsDownloaderProtocol { get }
}

public protocol FPSDKObjectsProtocol {
    var fileUploader: SDKFileUploaderProtocol { get }
    var fileDownloader: SDKFileDownloaderProtocol { get }
    var revisionUploader: SDKRevisionUploaderProtocol { get }
}

#if os(iOS)
public final class SDKObjects: SDKObjectsProtocol {
    public let fileDownloader: SDKFileDownloaderProtocol
    public let fileUploader: SDKFileUploaderProtocol
    public let nodeOperationPerformer: SDKNodeOperationPerformer?
    public let photoDownloader: SDKFileDownloaderProtocol
    public let photoUploader: SDKFileUploaderProtocol
    public let revisionUploader: SDKRevisionUploaderProtocol
    public let thumbnailDownloader: SDKThumbnailsDownloaderProtocol

    public init(
        fileDownloader: SDKFileDownloaderProtocol,
        fileUploader: SDKFileUploaderProtocol,
        nodeOperationPerformer: SDKNodeOperationPerformer?,
        photoDownloader: SDKFileDownloaderProtocol,
        photoUploader: SDKFileUploaderProtocol,
        revisionUploader: SDKRevisionUploaderProtocol,
        thumbnailDownloader: SDKThumbnailsDownloaderProtocol
    ) {
        self.fileDownloader = fileDownloader
        self.fileUploader = fileUploader
        self.nodeOperationPerformer = nodeOperationPerformer
        self.photoDownloader = photoDownloader
        self.photoUploader = photoUploader
        self.revisionUploader = revisionUploader
        self.thumbnailDownloader = thumbnailDownloader
    }
}

public final class FPSDKObjects: FPSDKObjectsProtocol {
    public let fileUploader: SDKFileUploaderProtocol
    public let fileDownloader: SDKFileDownloaderProtocol
    public let revisionUploader: SDKRevisionUploaderProtocol
    
    public init(
        fileUploader: SDKFileUploaderProtocol,
        fileDownloader: SDKFileDownloaderProtocol,
        revisionUploader: SDKRevisionUploaderProtocol
    ) {
        self.fileUploader = fileUploader
        self.fileDownloader = fileDownloader
        self.revisionUploader = revisionUploader
    }
}
#endif
