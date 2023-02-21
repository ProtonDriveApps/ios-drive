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

    private let block: FullUploadableBlock
    private let service: Service
    private let credentialProvider: CredentialProvider

    init(
        block: FullUploadableBlock,
        progressTracker: Progress,
        service: Service,
        credentialProvider: CredentialProvider
    ) {
        self.block = block
        self.service = service
        self.credentialProvider = credentialProvider
        self.remoteURL = block.remoteURL
        self.localURL = block.localURL
        super.init(progressTracker: progressTracker)
    }

    override func upload() {
        guard !isCancelled else { return }

        guard let credential = credentialProvider.clientCredential() else {
            return onCompletion(.failure(Uploader.Errors.noCredentialInCloudSlot))
        }

        do {
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
            onCompletion(.failure(error))
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

                guard let messageData = self.reader?.readData(ofLength: Config.chunkForUploadingStream),
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
        reader?.closeFile()

        if let preparedDataUrl = self.preparedDataURL {
            try? FileManager.default.removeItem(at: preparedDataUrl)
        }
    }

    deinit {
        closeStream()
    }
}

// MARK: - URLSessionTaskDelegate + URLSessionDataDelegate
extension URLSessionStreamBlockUploader: URLSessionDataDelegate {

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard !self.isCancelled,
              let error = error else { return }

        onCompletion(.failure(error))
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard !self.isCancelled else { return }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .decapitaliseFirstLetter
        if let error = try? decoder.decode(PDClient.ErrorResponse.self, from: data) {
            onCompletion(.failure(error.nsError()))

        } else {
            closeStream()
            cleanSession()
            onCompletion(.success(Void()))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, needNewBodyStream completionHandler: @escaping (InputStream?) -> Void) {
        completionHandler(boundStreams.input)
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
            onCompletion(.failure(Errors.streamingError))
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
