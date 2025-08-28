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

import PDCore
import PDCoreIOS
import Photos

public struct PhotoAssetData {
    public let identifier: PhotoIdentifier
    public let asset: PHAsset
    public let resource: PHAssetResource
    public let originalFilename: String
    public let fileExtension: String
    public let isOriginal: Bool

    public init(identifier: PhotoIdentifier, asset: PHAsset, resource: PHAssetResource, originalFilename: String, fileExtension: String, isOriginal: Bool) {
        self.identifier = identifier
        self.asset = asset
        self.resource = resource
        self.originalFilename = originalFilename
        self.fileExtension = fileExtension
        self.isOriginal = isOriginal
    }
}

public protocol PhotoLibraryAssetResource {
    func executePhoto(with data: PhotoAssetData) async throws -> PhotoAsset
    func executeVideo(with data: PhotoAssetData) async throws -> PhotoAsset
}

public class LocalPhotoLibraryAssetResource: PhotoLibraryAssetResource {
    fileprivate let contentResource: PhotoLibraryFileContentResource
    fileprivate let assetFactory: PhotoAssetFactory
    fileprivate let exifResource: PhotoLibraryExifResource
    private let localSettings: LocalSettings

    public init(
        contentResource: PhotoLibraryFileContentResource,
        assetFactory: PhotoAssetFactory,
        exifResource: PhotoLibraryExifResource,
        localSettings: LocalSettings
    ) {
        self.contentResource = contentResource
        self.assetFactory = assetFactory
        self.exifResource = exifResource
        self.localSettings = localSettings
    }

    public func executePhoto(with data: PhotoAssetData) async throws -> PhotoAsset {
        let url = try await contentResource.copyFile(with: data.resource)
        return try await execute(with: data, url: url, duration: nil)
    }

    public func executeVideo(with data: PhotoAssetData) async throws -> PhotoAsset {
        let url = try await contentResource.copyFile(with: data.resource)
        let duration = contentResource.getVideoDuration(at: url)
        return try await execute(with: data, url: url, duration: duration)
    }

    fileprivate func execute(with data: PhotoAssetData, url: URL, duration: Double?) async throws -> PhotoAsset {
        let isVideo = data.resource.isVideo()
        let exif = try await getExif(from: data.resource, url: url)
        let cameraInfo = await exifResource.getCameraInfo(at: url, isVideo: isVideo)
        let mime = getMimeType(from: data)
        let location = await exifResource.getLocation(at: url, isVideo: isVideo)
        let factoryData = PhotoAssetFactoryData(
            identifier: data.identifier,
            url: url,
            mimeType: mime,
            originalFilename: data.originalFilename,
            filenameExtension: data.fileExtension,
            width: data.asset.pixelWidth,
            height: data.asset.pixelHeight,
            exif: exif,
            isOriginal: data.isOriginal,
            duration: duration,
            camera: makeCameraInfo(data: data, camera: cameraInfo),
            location: location,
            tags: getPhotoTag(from: data, isRaw: mime.isRaw, isFrontCamera: cameraInfo.isFrontCamera)
        )
        return try assetFactory.makeAsset(from: factoryData)
    }

    private func getMimeType(from data: PhotoAssetData) -> MimeType {
        guard let type = MimeType(uti: data.resource.uniformTypeIdentifier) else {
            return MimeType(value: "application/octet-stream")
        }
        return type
    }

    private func getExif(from resource: PHAssetResource, url: URL) async throws -> PhotoAsset.Exif {
        if resource.isImage() {
            return exifResource.getPhotoExif(at: url)
        } else {
            return await exifResource.getVideoExif(at: url)
        }
    }

    private func makeCameraInfo(data: PhotoAssetData, camera: PhotoAssetMetadata.Camera) -> PhotoAssetMetadata.Camera {
        let earliestDate = Date(timeIntervalSince1970: 0)
        let defaultDate = Date(timeIntervalSince1970: -3061152000)
        // When EXIF creation date is empty, `data.asset.creationDate` is `Jan 1, 1904`, time stamp `-3061152000`
        var captureTime = camera.captureTime ?? data.asset.creationDate ?? camera.modificationTime ?? earliestDate
        // BE doesn't allow the default date, update captureTime when we get default date 
        if captureTime == defaultDate {
            captureTime = camera.modificationTime ?? earliestDate
        }
        captureTime = captureTime > earliestDate ? captureTime : earliestDate

        return PhotoAssetMetadata.Camera(
            captureTime: captureTime,
            device: camera.device,
            modificationTime: camera.modificationTime,
            orientation: camera.orientation,
            subjectCoordinates: camera.subjectCoordinates,
            isFrontCamera: camera.isFrontCamera
        )
    }

    private func getPhotoTag(from data: PhotoAssetData, isRaw: Bool, isFrontCamera: Bool) -> [PhotoTag] {
        if Constants.buildType.isQaOrBelow && localSettings.isPhotoTagsAnalysisDisabled {
            return []
        }
        let asset = data.asset
        var type: [PhotoTag] = []
        if asset.mediaSubtypes.contains(.photoPanorama) { type.append(PhotoTag.panoramas) }
        if asset.mediaSubtypes.contains(.photoScreenshot) { type.append(PhotoTag.screenshots) }
        if asset.mediaSubtypes.contains(.photoLive) { type.append(PhotoTag.livePhotos) }

        if asset.representsBurst { type.append(PhotoTag.bursts) }
        if asset.mediaType == .video { type.append(PhotoTag.videos) }
        if isFrontCamera { type.append(PhotoTag.selfies) }
        if asset.isFavorite { type.append(PhotoTag.favorites) }
        if isRaw { type.append(PhotoTag.raw) }

        if asset.mediaSubtypes.contains(.photoDepthEffect), data.resource.isAdjustedImage() {
            type.append(PhotoTag.portraits)
        }

        return type
    }
}

public class TagsLocalPhotoLibraryAssetResource: LocalPhotoLibraryAssetResource {

    override public func executePhoto(with data: PhotoAssetData) async throws -> PhotoAsset {
        let url = try await contentResource.copyFile(with: data.resource)
        defer {
            try? FileManager.default.removeItem(at: url)
        }
        return try await execute(with: data, url: url, duration: nil)
    }

    override public func executeVideo(with data: PhotoAssetData) async throws -> PhotoAsset {
        assert(false, "This method should not be called.")
        let url = try await contentResource.copyFile(with: data.resource)
        defer {
            try? FileManager.default.removeItem(at: url)
        }
        let duration = contentResource.getVideoDuration(at: url)
        return try await execute(with: data, url: url, duration: duration)
    }
}
