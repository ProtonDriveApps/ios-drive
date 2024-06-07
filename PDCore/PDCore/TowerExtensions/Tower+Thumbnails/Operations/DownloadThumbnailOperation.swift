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

class DownloadThumbnailOperation: ThumbnailDecryptorOperation {
    private let thumbnailURL: URL?
    private let thumbnailIdentifier: ThumbnailIdentifier?
    private let downloader: ThumbnailDownloader
    let urlFetchInteractor: ThumbnailURLFetchInteractor
    private var redownloadTask: Task<Void, Error>?

    init(url: URL?, thumbnailIdentifier: ThumbnailIdentifier?, downloader: ThumbnailDownloader, decryptor: ThumbnailDecryptor, identifier: NodeIdentifier, urlFetchInteractor: ThumbnailURLFetchInteractor) {
        self.thumbnailURL = url
        self.thumbnailIdentifier = thumbnailIdentifier
        self.downloader = downloader
        self.urlFetchInteractor = urlFetchInteractor
        super.init(encryptedThumbnail: nil, decryptor: decryptor, identifier: identifier)
    }

    convenience init(
        model: InProgressThumbnail,
        downloader: ThumbnailDownloader,
        decryptor: ThumbnailDecryptor,
        urlFetchInteractor: ThumbnailURLFetchInteractor
    ) {
        self.init(url: model.url, thumbnailIdentifier: model.thumbnailIdentifier, downloader: downloader, decryptor: decryptor, identifier: model.revisionId.nodeIdentifier, urlFetchInteractor: urlFetchInteractor)
    }
    
    override func main() {
        guard !isCancelled,
              let thumbnailURL = thumbnailURL else {
            return
        }

        download(thumbnailURL)
    }

    func download(_ thumbnailURL: URL) {
        downloader.download(url: thumbnailURL) { [weak self] result in
            guard let self = self,
                  !self.isCancelled else { return }

            switch result {
            case .success(let encryptedThumbnail):
                self.decrypt(encryptedThumbnail)
            case .failure(let error):
                self.handleDownloadError(error)
            }
        }
    }

    private func handleDownloadError(_ error: Error) {
        if error as? URLSessionThumbnailDownloader.ThumbnailDownloadError == .notFound, let thumbnailIdentifier {
            // URL is expired, need to refetch. This is only supported for thumbnails with ids for now.
            redownloadURL(with: thumbnailIdentifier)
        } else {
            self.finishOperationWithFailure(error)
        }
    }

    private func redownloadURL(with thumbnailIdentifier: ThumbnailIdentifier) {
        redownloadTask = Task { [weak self] in
            guard let self = self, !self.isCancelled else { return }
            let url = try await self.urlFetchInteractor.execute(thumbnailId: thumbnailIdentifier.thumbnailId, volumeId: thumbnailIdentifier.volumeId)
            guard !self.isCancelled else { return }
            self.download(url)
        }
    }

    override func cancel() {
        super.cancel()
        redownloadTask?.cancel()
        downloader.cancel()
    }
}

protocol ThumbnailDownloader {
    func download(url: URL, completion: @escaping(Result<Data, Error>) -> Void)
    func cancel()
}

final class URLSessionThumbnailDownloader: ThumbnailDownloader {
    private let session: URLSession
    private var task: URLSessionDataTask?
    private var isCancelled = false

    init(session: URLSession) {
        self.session = session
    }

    func download(url: URL, completion: @escaping (Result<Data, Error>) -> Void) {
        guard !isCancelled else { return }

        task = session.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self, !self.isCancelled else {
                return
            }

            if let error = error as? NSError {
                return completion(.failure(error))
            }

            let responseCode = (response as? HTTPURLResponse)?.statusCode

            guard let encryptedThumbnail = data,
                  responseCode == self.okStatusCode else {
                if responseCode == 404 {
                    completion(.failure(ThumbnailDownloadError.notFound))
                } else {
                    completion(.failure(ThumbnailDownloadError.other(code: responseCode)))
                }
                return
            }

            completion(.success(encryptedThumbnail))
        }

        task?.resume()
    }

    func cancel() {
        isCancelled = true
        task?.cancel()
        task = nil
    }

    private var okStatusCode: Int { 200 }

    enum ThumbnailDownloadError: Error, Equatable {
        case notFound
        case other(code: Int?)
    }
}
