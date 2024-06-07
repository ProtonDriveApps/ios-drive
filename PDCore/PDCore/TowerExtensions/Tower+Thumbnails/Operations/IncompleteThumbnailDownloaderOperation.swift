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

import PDClient

final class IncompleteThumbnailDownloaderOperation: DownloadThumbnailOperation {
    private let id: RevisionIdentifier
    private let cloud: ThumbnailCloudClient
    private let typeStrategy: ThumbnailTypeStrategy

    init(id: RevisionIdentifier, cloud: ThumbnailCloudClient, downloader: ThumbnailDownloader, decryptor: ThumbnailDecryptor, typeStrategy: ThumbnailTypeStrategy, urlFetchInteractor: ThumbnailURLFetchInteractor) {
        self.id = id
        self.cloud = cloud
        self.typeStrategy = typeStrategy
        super.init(url: nil, thumbnailIdentifier: nil, downloader: downloader, decryptor: decryptor, identifier: id.nodeIdentifier, urlFetchInteractor: urlFetchInteractor)
    }

    convenience init(
        model: IncompleteThumbnail,
        cloud: ThumbnailCloudClient,
        downloader: ThumbnailDownloader,
        decryptor: ThumbnailDecryptor,
        typeStrategy: ThumbnailTypeStrategy,
        urlFetchInteractor: ThumbnailURLFetchInteractor
    ) {
        self.init(id: model.revisionId, cloud: cloud, downloader: downloader, decryptor: decryptor, typeStrategy: typeStrategy, urlFetchInteractor: urlFetchInteractor)
    }

    override func main() {
        guard !self.isCancelled else { return }

        let thumbnailType = typeStrategy.getType().rawValue
        let parameters = RevisionThumbnailParameters(shareId: id.share, fileId: id.file, revisionId: id.revision, type: Int(thumbnailType))
        cloud.downloadThumbnailURL(parameters: parameters) { [weak self] result in
            guard let self = self,
                  !self.isCancelled else {
                return
            }

            switch result {
            case .success(let thumbnailURL):
                self.download(thumbnailURL)

            case .failure(let error):
                self.finishOperationWithFailure(error)
            }
        }
    }
}
