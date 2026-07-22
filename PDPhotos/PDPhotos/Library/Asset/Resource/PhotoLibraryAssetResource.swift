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

public struct AppendedAssetData {
    public var cameraInfo: PhotoAssetMetadata.Camera
    public var location: PhotoAssetMetadata.Location?

    public init(cameraInfo: PhotoAssetMetadata.Camera, location: PhotoAssetMetadata.Location?) {
        self.cameraInfo = cameraInfo
        self.location = location
    }
}

public protocol PhotoLibraryAssetResource {
    func executePhoto(with data: PhotoAssetData) async throws -> PhotoAsset
    func executeVideo(with data: PhotoAssetData, appendedAssetData: AppendedAssetData?) async throws -> PhotoAsset
}

public class LocalPhotoLibraryAssetResource: PhotoLibraryAssetResource {
    fileprivate let contentResource: PhotoLibraryFileContentResource
    fileprivate let assetFactory: PhotoAssetFactory
    fileprivate let exifResource: PhotoLibraryExifResource
    private let localSettings: LocalSettings
    private let rootFolderRepository: PhotosRootFolderRepository
    private let encryptionResource: EncryptionResource

    public init(
        contentResource: PhotoLibraryFileContentResource,
        assetFactory: PhotoAssetFactory,
        exifResource: PhotoLibraryExifResource,
        localSettings: LocalSettings,
        rootFolderRepository: PhotosRootFolderRepository,
        encryptionResource: EncryptionResource
    ) {
        self.contentResource = contentResource
        self.assetFactory = assetFactory
        self.exifResource = exifResource
        self.localSettings = localSettings
        self.rootFolderRepository = rootFolderRepository
        self.encryptionResource = encryptionResource
    }

    public func executePhoto(with data: PhotoAssetData) async throws -> PhotoAsset {
        let (properties, contentHash, dataSize) = try await readImageProperty(from: data.resource, creationDate: data.asset.creationDate)
        let cameraInfo = exifResource.getCameraInfo(from: properties)
        let mime = getMimeType(from: data)
        let location = getLocation(from: data.asset, or: properties)

        let factoryData = PhotoAssetFactoryData(
            identifier: data.identifier,
            mimeType: mime,
            originalFilename: data.originalFilename,
            filenameExtension: data.fileExtension,
            width: data.asset.pixelWidth,
            height: data.asset.pixelHeight,
            exif: Data(),
            isOriginal: data.isOriginal,
            duration: nil,
            camera: makeCameraInfo(data: data, camera: cameraInfo),
            location: location,
            tags: getPhotoTag(from: data, isRaw: mime.isRaw, isFrontCamera: cameraInfo.isFrontCamera),
            contentHash: contentHash,
            dataSize: dataSize,
            resourceType: data.resource.type.rawValue
        )
        return try assetFactory.makeAsset(from: factoryData)
    }

    /// - Parameters:
    ///   - appendedAssetData: For Live photo video, Live photo video can't read AVAsset
    public func executeVideo(with data: PhotoAssetData, appendedAssetData: AppendedAssetData?) async throws -> PhotoAsset {
        let (contentHash, dataSize) = try await readVideoContentHash(from: data.resource, creationDate: data.asset.creationDate)
        let mime = getMimeType(from: data)

        let cameraInfo: PhotoAssetMetadata.Camera
        let location: PhotoAssetMetadata.Location?
        let duration: Double
        if let appendedAssetData {
            cameraInfo = appendedAssetData.cameraInfo
            location = appendedAssetData.location
            duration = 1.4 // Approximate value for live photo, can't get correct value since AVAsset is not available
        } else {
            let avAsset = try await readAvAsset(from: data.asset)
            cameraInfo = await exifResource.getCameraInfo(asset: avAsset)
            location = await getLocation(from: data.asset, or: avAsset)
            duration = data.asset.duration
        }

        let factoryData = PhotoAssetFactoryData(
            identifier: data.identifier,
            mimeType: mime,
            originalFilename: data.originalFilename,
            filenameExtension: data.fileExtension,
            width: data.asset.pixelWidth,
            height: data.asset.pixelHeight,
            exif: Data(),
            isOriginal: data.isOriginal,
            duration: duration,
            camera: makeCameraInfo(data: data, camera: cameraInfo),
            location: location,
            tags: getPhotoTag(from: data, isRaw: mime.isRaw, isFrontCamera: cameraInfo.isFrontCamera),
            contentHash: contentHash,
            dataSize: dataSize,
            resourceType: data.resource.type.rawValue
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

    private func getLocation(from asset: PHAsset, or properties: NSDictionary) -> PhotoAssetMetadata.Location? {
        if let assetLocation = asset.location {
            let coordinate = assetLocation.coordinate
            return PhotoAssetMetadata.Location(latitude: coordinate.latitude, longitude: coordinate.longitude)
        } else {
            return exifResource.getLocation(from: properties)
        }
    }

    private func getLocation(from asset: PHAsset, or avAsset: AVAsset) async -> PhotoAssetMetadata.Location? {
        if let assetLocation = asset.location {
            let coordinate = assetLocation.coordinate
            return PhotoAssetMetadata.Location(latitude: coordinate.latitude, longitude: coordinate.longitude)
        } else {
            return await exifResource.getLocation(asset: avAsset)
        }
    }

    private func makeCameraInfo(data: PhotoAssetData, camera: PhotoAssetMetadata.Camera) -> PhotoAssetMetadata.Camera {
        let earliestDate = Date(timeIntervalSince1970: 0)
        var captureTime = camera.captureTime ?? data.asset.creationDate ?? camera.modificationTime ?? earliestDate
        // When EXIF creation date is empty, `data.asset.creationDate` is `Jan 1, 1904`, time stamp `-3061152000`
        // BE doesn't allow the default date, update captureTime when we get default date
        if captureTime == Date(timeIntervalSince1970: -3061152000) {
            captureTime = camera.modificationTime ?? earliestDate
        }
        captureTime = captureTime > earliestDate ? captureTime : earliestDate
        
        if captureTime.timeIntervalSince1970 < -6847804800 || captureTime.timeIntervalSince1970 > 4102444799 {
            // These are current BE constraints, can change any time, but we want to log to understand which data source is giving us nonsense data.
            // In next iteration, we can try improve the fallbacking
            let captureTimeFromExif = camera.captureTime.map { "\($0)" } ?? "nil"
            let creationDateFromAsset = data.asset.creationDate.map { "\($0)" } ?? "nil"
            let modificationTimeFromExif = camera.modificationTime.map { "\($0)" } ?? "nil"
            let context = "captureTime: \(captureTime), captureTimeFromExif: \(captureTimeFromExif), creationDateFromAsset: \(creationDateFromAsset), modificationTimeFromExif: \(modificationTimeFromExif)"
            Log.error("Photo with invalid capture time", error: nil, domain: .photosProcessing, context: LogContext(context))
        }

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

// MARK: - in place read data
extension LocalPhotoLibraryAssetResource {
    /// Read image properties dictionary and content hash
    /// - Returns: (Properties dictionary, content hash, data size)
    private func readImageProperty(from resource: PHAssetResource, creationDate: Date?) async throws -> (NSDictionary, String, Int) {
        let sha1 = SHA1DigestBuilder()
        let resourceOption = PHAssetResourceRequestOptions()
        resourceOption.isNetworkAccessAllowed = true
        let key = try rootFolderRepository.getEncryptionInfo().hashKey
        let encryptionResource = self.encryptionResource
        let accumulator = IncrementalImagePropertyAccumulator.imageIO()
        var dataSize = 0

        return try await withCheckedThrowingContinuation { continuation in
            PHAssetResourceManager.default().requestData(for: resource, options: resourceOption) { chunk in
                dataSize += chunk.count
                sha1.add(chunk)
                accumulator.append(chunk)
            } completionHandler: { error in
                if let error {
                    Log.debug("Local identifier \(resource.assetLocalIdentifier), createtionDate: \(creationDate ?? .distantPast)", domain: .photosProcessing)
                    Log.error("Request image data from iCloud failed, resource type: \(resource.type)", error: error, domain: .photosProcessing)
                    continuation.resume(throwing: Errors.cloudAssetNotAvailable)
                } else {
                    guard let properties = accumulator.finalize() else {
                        continuation.resume(throwing: Errors.dataNotAvailable)
                        return
                    }
                    let sha1Hex = sha1.getResult().hexString()
                    do {
                        let contentHash = try encryptionResource.makeHmac(string: sha1Hex, hashKey: key)
                        continuation.resume(returning: (properties, contentHash, dataSize))
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    /// - Returns: (content hash, data size)
    private func readVideoContentHash(from resource: PHAssetResource, creationDate: Date?) async throws -> (String, Int) {
        let sha1 = SHA1DigestBuilder()
        let resourceOption = PHAssetResourceRequestOptions()
        resourceOption.isNetworkAccessAllowed = true
        let key = try rootFolderRepository.getEncryptionInfo().hashKey
        let encryptionResource = self.encryptionResource
        var dataSize = 0
        return try await withCheckedThrowingContinuation { continuation in
            PHAssetResourceManager.default().requestData(for: resource, options: resourceOption) { data in
                dataSize += data.count
                sha1.add(data)
            } completionHandler: { error in
                if let error {
                    Log.debug("Local identifier \(resource.assetLocalIdentifier), createtionDate: \(creationDate ?? .distantPast)", domain: .photosProcessing)
                    Log.error("Request video data from iCloud failed, resource type: \(resource.type)", error: error, domain: .photosProcessing)
                    continuation.resume(throwing: Errors.cloudAssetNotAvailable)
                } else {
                    let sha1Hex = sha1.getResult().hexString()
                    do {
                        let contentHash = try encryptionResource.makeHmac(string: sha1Hex, hashKey: key)
                        continuation.resume(returning: (contentHash, dataSize))
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    private func readAvAsset(from asset: PHAsset) async throws -> AVAsset {
        let videoOption = PHVideoRequestOptions()
        videoOption.isNetworkAccessAllowed = true
        videoOption.version = .current
        videoOption.deliveryMode = .automatic
        return try await withCheckedThrowingContinuation { continuation in
            PHImageManager.default().requestAVAsset(forVideo: asset, options: videoOption) { avAsset, _, info in
                if let avAsset {
                    continuation.resume(returning: avAsset)
                } else {
                    Log.error("Failed to load AVAsset: \(info?.description ?? "")", error: nil, domain: .photosProcessing)
                    continuation.resume(throwing: Errors.avAssetNotAvailable)
                }
            }
        }
    }
}

extension LocalPhotoLibraryAssetResource {
    public enum Errors: Error {
        case avAssetNotAvailable
        case dataNotAvailable
        case selfIsReleased
        case cloudAssetNotAvailable
    }
}

public class TagsLocalPhotoLibraryAssetResource: LocalPhotoLibraryAssetResource {

    override public func executeVideo(with data: PhotoAssetData, appendedAssetData: AppendedAssetData?) async throws -> PhotoAsset {
        return try await super.executeVideo(with: data, appendedAssetData: nil)
    }
}
