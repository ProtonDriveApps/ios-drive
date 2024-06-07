// Copyright (c) 2024 Proton AG
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
#if targetEnvironment(simulator)

// we don't want to run this code on iOS simulator because of the issue with the simulator runtime: https://developer.apple.com/forums/thread/718198
public enum Archiver {
    public static func archive(_ source: URL, to destination: URL) throws { 
        try? FileManager.default.moveItem(at: source, to: destination)
    }
    public static func unarchive(_ source: URL, to directory: URL) throws { 
        try? FileManager.default.moveItem(at: source, to: directory.appendingPathComponent(source.lastPathComponent))
    }
}
#else

import AppleArchive
import System

public enum Archiver {
    /// The header fields to include in the archive.
    static let fields = ArchiveHeader.FieldKeySet("TYP,PAT,LNK,DEV,UID,GID,MOD,FLG,MTM,CTM,SH2,DAT,SIZ")!

    /// Default permissions for the archive.
    static let permissions = FilePermissions(rawValue: 0o644)

    static let algorithm: ArchiveCompression = .lzfse

    public static func archive(_ source: URL, to destination: URL) throws {
        var isDirectory: ObjCBool = false

        guard FileManager.default.fileExists(atPath: source.path, isDirectory: &isDirectory) else {
            throw POSIXError(.ENOENT)
        }

        guard let writeStream = byteStream(writeTo: FilePath(destination.path)) else {
            throw POSIXError(.EBADF)
        }
        defer { try? writeStream.close() }

        guard let compressionStream = compressionStream(algorithm: algorithm, writeStream: writeStream) else {
            throw POSIXError(.EIO)
        }
        defer { try? compressionStream.close() }

        guard let encoderStream = ArchiveStream.encodeStream(writingTo: compressionStream) else {
            throw POSIXError(.EIO)
        }
        defer { try? encoderStream.close() }

        if isDirectory.boolValue {
            try encoderStream.writeDirectoryContents(archiveFrom: FilePath(source.path), keySet: fields)
        } else {
            let directoryPath = FilePath(source.deletingLastPathComponent().path)
            let header = ArchiveHeader(keySet: fields, directory: directoryPath, path: FilePath(source.lastPathComponent), flags: [])!
            try Data(contentsOf: source, options: .mappedIfSafe).withUnsafeBytes {
                header.append(.blob(key: ArchiveHeader.FieldKey("DAT"), size: UInt64($0.count)))
                try encoderStream.writeHeader(header)
                try encoderStream.writeBlob(key: ArchiveHeader.FieldKey("DAT"), from: $0)
            }
        }
    }

    public static func unarchive(_ source: URL, to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        guard let readStream = byteStream(readFrom: FilePath(source.path)) else {
            throw POSIXError(.EBADF)
        }
        defer { try? readStream.close() }

        guard let decompressionStream = decompressionStream(readStream: readStream) else {
            throw POSIXError(.EIO)
        }
        defer { try? decompressionStream.close() }

        guard let decodingStream = decodingStream(from: decompressionStream) else {
            throw POSIXError(.EIO)
        }
        defer { try? decodingStream.close() }

        guard let extractorStream = extractorStream(to: FilePath(directory.path)) else {
            throw POSIXError(.EIO)
        }
        defer { try? extractorStream.close() }

        _ = try ArchiveStream.process(readingFrom: decodingStream, writingTo: extractorStream)
    }

    private static func byteStream(readFrom path: FilePath) -> ArchiveByteStream? {
        return ArchiveByteStream.fileStream(path: path, mode: .readOnly, options: [.noFollow], permissions: permissions)
    }

    private static func byteStream(writeTo path: FilePath) -> ArchiveByteStream? {
        return ArchiveByteStream.fileStream(path: path, mode: .writeOnly, options: [.create, .truncate, .noFollow], permissions: permissions)
    }

    private static func compressionStream(algorithm: ArchiveCompression, writeStream: ArchiveByteStream) -> ArchiveByteStream? {
        return ArchiveByteStream.compressionStream(using: algorithm, writingTo: writeStream, flags: [.archiveDeduplicateData])
    }

    private static func decompressionStream(readStream: ArchiveByteStream) -> ArchiveByteStream? {
        return ArchiveByteStream.decompressionStream(readingFrom: readStream)
    }

    private static func encodingStream(writeStream: ArchiveByteStream) -> ArchiveStream? {
        return ArchiveStream.encodeStream(writingTo: writeStream)
    }

    private static func decodingStream(from stream: ArchiveByteStream) -> ArchiveStream? {
        return ArchiveStream.decodeStream(readingFrom: stream)
    }

    private static func extractorStream(to path: FilePath) -> ArchiveStream? {
        return ArchiveStream.extractStream(extractingTo: path, flags: .ignoreOperationNotPermitted)
    }
}
#endif
