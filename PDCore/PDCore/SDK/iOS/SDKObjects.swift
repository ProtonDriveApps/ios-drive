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
    var fileUploader: SDKFileUploaderProtocol { get }
    var fileDownloader: SDKFileDownloaderProtocol { get }
    var fileThumbnailDownloader: SDKThumbnailsDownloaderProtocol { get }
    var photoUploader: SDKFileUploaderProtocol { get }
    var photoDownloader: SDKFileDownloaderProtocol { get }
    var photoThumbnailDownloader: SDKThumbnailsDownloaderProtocol { get }
    var revisionUploader: SDKRevisionUploaderProtocol { get }
    var nodeOperationPerformer: SDKNodeOperationPerformer? { get }
}

public protocol FPSDKObjectsProtocol {
    var fileUploader: SDKFileUploaderProtocol { get }
    var fileDownloader: SDKFileDownloaderProtocol { get }
    var revisionUploader: SDKRevisionUploaderProtocol { get }
}

#if os(iOS)
public final class SDKObjects: SDKObjectsProtocol {
    public let fileUploader: SDKFileUploaderProtocol
    public let fileDownloader: SDKFileDownloaderProtocol
    public let fileThumbnailDownloader: SDKThumbnailsDownloaderProtocol
    public let photoUploader: SDKFileUploaderProtocol
    public let photoDownloader: SDKFileDownloaderProtocol
    public let photoThumbnailDownloader: SDKThumbnailsDownloaderProtocol
    public let revisionUploader: SDKRevisionUploaderProtocol
    public let nodeOperationPerformer: SDKNodeOperationPerformer?
    
    public init(
        fileUploader: SDKFileUploaderProtocol,
        fileDownloader: SDKFileDownloaderProtocol,
        fileThumbnailDownloader: SDKThumbnailsDownloaderProtocol,
        photoUploader: SDKFileUploaderProtocol,
        photoDownloader: SDKFileDownloaderProtocol,
        photoThumbnailDownloader: SDKThumbnailsDownloaderProtocol,
        revisionUploader: SDKRevisionUploaderProtocol,
        nodeOperationPerformer: SDKNodeOperationPerformer?
    ) {
        self.fileUploader = fileUploader
        self.fileDownloader = fileDownloader
        self.fileThumbnailDownloader = fileThumbnailDownloader
        self.photoUploader = photoUploader
        self.photoDownloader = photoDownloader
        self.photoThumbnailDownloader = photoThumbnailDownloader
        self.revisionUploader = revisionUploader
        self.nodeOperationPerformer = nodeOperationPerformer
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
