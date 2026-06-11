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
import PDCore

public protocol FileVerificationProtocol {
    
    func computeDigestData(file: URL) async throws -> Data
    
    func verifyDigest(
        file: URL,
        against expectedValue: String?,
        revisionUid: String,
        revisionCreationTime: Date?,
        revisionSize: Int64,
        checksumVerified: Bool
    ) async throws
}

public enum FileVerificationError: LocalizedError {
    case downloadVerificationFailed(expectedSHA1: String, computedSHA1: String)
    case uploadVerificationFailed(underlyingCause: String)
    
    public var errorDescription: String? {
        switch self {
        case .downloadVerificationFailed:
            return "Download verification failed, please try again later"
        case .uploadVerificationFailed:
            return "Upload verification failed, please try again later"
        }
    }
}

public final class FileVerifier: FileVerificationProtocol {
    
    #if os(macOS)
    @usableFromInline static let defaultChunkSize = 64 * 1024 * 1024
    #elseif os(iOS)
    @usableFromInline static let defaultChunkSize = 6 * 1024
    #endif
    
    private let chunkSize: Int
    private let digestBuilderFactory: () -> DigestBuilder
    private let observabilityReporter: ObservabilityReporterProtocol
    private let dateFormatter = ISO8601DateFormatter.default
    
    public init(digestBuilderFactory: @escaping () -> DigestBuilder = { SHA1DigestBuilder() },
                chunkSize: Int = defaultChunkSize,
                observabilityReporter: ObservabilityReporterProtocol) {
        self.chunkSize = chunkSize
        self.digestBuilderFactory = digestBuilderFactory
        self.observabilityReporter = observabilityReporter
    }
    
    public func computeDigestData(file: URL) async throws -> Data {
        try await Task(priority: .userInitiated) {
            let handle = try FileHandle(forReadingFrom: file)
            defer { try? handle.close() }
            
            let digestBuilder = digestBuilderFactory()
            
            var isFinished = false
            while isFinished == false {
                try autoreleasepool {
                    let data = try handle.read(upToCount: chunkSize)
                    if let data = data, !data.isEmpty {
                        digestBuilder.add(data)
                    } else {
                        isFinished = true
                    }
                }
            }
            return digestBuilder.getResult()
        }.value
    }
    
    public func verifyDigest(
        file: URL,
        against expectedValue: String?,
        revisionUid: String,
        revisionCreationTime: Date?,
        revisionSize: Int64,
        checksumVerified: Bool
    ) async throws {
        guard let expectedValue else {
            // ignore check if expected value is not available
            Log.info("File verification skipped. No expected value. Revision UID: \(revisionUid)", domain: .syncing)
            await observabilityReporter.reportFileVerification(
                .download(result: .skipped, fileSize: revisionSize, checksumVerified: checksumVerified)
            )
            return
        }
        guard let expectedData = Data(hex: expectedValue) else {
            // ignore check if expected value is not in a correct format, which for SHA1 is a hex string
            Log.error("File verification skipped. Expected value is not a hex string. Revision UID: \(revisionUid)", domain: .syncing, sendToSentryIfPossible: true)
            await observabilityReporter.reportFileVerification(
                .download(result: .skipped, fileSize: revisionSize, checksumVerified: checksumVerified)
            )
            return
        }
        
        let computedDigest: Data
        do {
            computedDigest = try await computeDigestData(file: file)
        } catch {
            await observabilityReporter.reportFileVerification(
                .download(result: .skipped, fileSize: revisionSize, checksumVerified: checksumVerified)
            )
            Log.error("File verification skipped. Unable to read file. Revision UID: \(revisionUid). Error: \(error)", domain: .syncing)
            return
        }
        
        guard computedDigest == expectedData else {
            await observabilityReporter.reportFileVerification(
                .download(result: .failure, fileSize: revisionSize, checksumVerified: checksumVerified)
            )
            if checksumVerified {
                Log.error(
                    "File verification failed. Digest mismatch. Revision UID: \(revisionUid), revision creation time: \(dateFormatter.string(revisionCreationTime) ?? "unknown")",
                    domain: .syncing
                )
                throw FileVerificationError.downloadVerificationFailed(
                    expectedSHA1: expectedValue, computedSHA1: computedDigest.hexString()
                )
            } else {
                Log.info(
                    "File verification failed. Digest mismatch, checksumVerified is false. Revision UID: \(revisionUid), revision creation time: \(dateFormatter.string(revisionCreationTime) ?? "unknown")",
                    domain: .syncing,
                    sendToSentryIfPossible: true
                )
                // Allow user to complete download when `checksumVerified` is `false`
                return
            }
        }
        
        Log.info("File verification succeeded. Revision UID: \(revisionUid)", domain: .syncing)
        await observabilityReporter.reportFileVerification(
            .download(result: .success, fileSize: revisionSize, checksumVerified: checksumVerified)
        )
    }
}
