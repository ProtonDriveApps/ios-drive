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
import PDClient

struct Streams {
    let input: InputStream
    let output: OutputStream
}

final class URLSessionStreamBlockUploader: URLSessionContentUploader {

    /// URL on the cloud for data to be uploaded to
    private let remoteURL: URL
    /// Cypherdata as it should appear on the Cloud
    private let localURL: URL
    /// Data that will be transmitted in the UploadTask, usually cypherdata + some prefix with headers
    private var preparedDataURL: URL?

    private var reader: FileHandle?
    private var canWrite: Bool = false
    private var timer: Timer!
    private var boundStreams: Streams!

    private let uploadBlock: UploadBlock
    private let service: Service
    private let credentialProvider: CredentialProvider

    init(
        uploadBlock: UploadBlock,
        fullUploadableBlock: FullUploadableBlock,
        progressTracker: Progress,
        service: Service,
        credentialProvider: CredentialProvider
    ) {
        self.uploadBlock = uploadBlock
        self.service = service
        self.credentialProvider = credentialProvider
        self.remoteURL = fullUploadableBlock.remoteURL
        self.localURL = fullUploadableBlock.localURL
        super.init(progressTracker: progressTracker)
    }

    private var completion: Completion?

    override func upload(completion: @escaping Completion) {
        guard !isCancelled else { return }

        guard let credential = credentialProvider.clientCredential() else {
            return completion(.failure(FileUploaderError.noCredentialFound))
        }

        self.completion = completion

        do {
            guard FileManager.default.fileExists(atPath: localURL.path) else {
                throw ContentCleanedError(area: .block)
            }

            let endpoint = try UploadBlockFromFileEndpoint(url: remoteURL, data: localURL, chunkSize: Constants.maxBlockChunkSize, credential: credential, service: service)
            reader = try FileHandle(forReadingFrom: endpoint.onDiskUrl)

            makeBoundStreams()
            startStreamLoop()

            let task = session.uploadTask(withStreamedRequest: endpoint.request)
            progressTracker.addChild(task.progress, withPendingUnitCount: 1)

            self.task = task
            preparedDataURL = endpoint.onDiskUrl

            task.resume()

        } catch {
            completion(.failure(error))
        }
    }

    override func cancel() {
        super.cancel()
        closeStream()
    }

    // MARK: - Streaming

    private func makeBoundStreams() {
        var inputOrNil: InputStream?
        var outputOrNil: OutputStream?

        Stream.getBoundStreams(withBufferSize: Constants.maxBlockChunkSize, inputStream: &inputOrNil, outputStream: &outputOrNil)
        guard let input = inputOrNil, let output = outputOrNil else {
            fatalError("Both inputStream and outputStream will contain non-nil streams.")
        }
        self.boundStreams = Streams(input: input, output: output)

        output.delegate = self
        output.schedule(in: RunLoop.main, forMode: .default)
        output.open()
    }

    private func startStreamLoop() {
        DispatchQueue.main.async {
            self.timer = Timer.scheduledTimer(withTimeInterval: Config.timingForUploadingStream, repeats: true) { [weak self] timer in
                guard let self = self,
                      self.canWrite else { return }

                guard let messageData = try? self.reader?.read(upToCount: Config.chunkForUploadingStream),
                      case let messageCount = messageData.count,
                      messageCount != 0 else {
                    self.boundStreams.output.close()
                    timer.invalidate()
                    return
                }

                let bytesWritten: Int = messageData.withUnsafeBytes { (buffer: UnsafePointer<UInt8>) in
                    self.canWrite = false
                    return self.boundStreams.output.write(buffer, maxLength: messageCount)
                }
                assert(bytesWritten == messageCount)
            }
        }
    }

    private func closeStream() {
        timer?.invalidate()
        try? reader?.close()

        if let preparedDataUrl = self.preparedDataURL {
            try? FileManager.default.removeItem(at: preparedDataUrl)
        }
    }

    deinit {
        closeStream()
    }

    func completeWithFailure(_ error: Error) {
        self.completion?(.failure(error))
        self.completion = nil
    }
}

// MARK: - URLSessionTaskDelegate + URLSessionDataDelegate
extension URLSessionStreamBlockUploader: URLSessionDataDelegate {

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard !self.isCancelled,
              let error = error else { return }

        self.completeWithFailure(error)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard !self.isCancelled else { return }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .driveImplementationOfDecapitaliseFirstLetter
        if let error = try? decoder.decode(PDClient.ErrorResponse.self, from: data) {
            self.completeWithFailure(error.nsError())

        } else {
            closeStream()
            cleanSession()
            saveUploadedBlockState()
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, needNewBodyStream completionHandler: @escaping (InputStream?) -> Void) {
        completionHandler(boundStreams.input)
    }

    func urlSession(
        _ session: URLSession, didReceive challenge: URLAuthenticationChallenge
    ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard let trust = challenge.protectionSpace.serverTrust else { return (.performDefaultHandling, nil) }
        let credential = URLCredential(trust: trust)
        return (.useCredential, credential)
    }
}

extension URLSessionStreamBlockUploader: StreamDelegate {

    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        guard aStream == boundStreams.output else {
            return
        }

        if eventCode.contains(.hasSpaceAvailable) {
            canWrite = true
        }

        if eventCode.contains(.errorOccurred) {
            self.completeWithFailure(Errors.streamingError)
        }
    }

}

extension URLSessionStreamBlockUploader {
    private enum Config {
        static let chunkForUploadingStream = Constants.maxBlockChunkSize
        static let timingForUploadingStream: TimeInterval = 0.1
    }

    enum Errors: Error {
        case unableToReadLocalUrl
        case streamingError
    }
}

extension URLSessionStreamBlockUploader {
    private func saveUploadedBlockState() {
        guard let moc = uploadBlock.moc else { return }

        moc.performAndWait { [weak self] in
            guard let self, !self.isCancelled else { return }
            do {
                uploadBlock.isUploaded = true
                try moc.saveOrRollback()
                self.completion?(.success)
                self.completion = nil
            } catch {
                self.completeWithFailure(error)
            }
        }
    }
}
