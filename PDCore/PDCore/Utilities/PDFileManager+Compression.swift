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

#if targetEnvironment(simulator)

// we don't wan't to run this code on iOS simulator because of the issue with the simulator runtime: https://developer.apple.com/forums/thread/718198

#else

import Foundation
import AppleArchive
import System

// MARK: - Constants used for compression

public extension PDFileManager {
    
    private static var filePermissions: FilePermissions = .init(rawValue: 0o644)
    
    private static var compressionAlgorithm: ArchiveCompression = .lzfse
    
    static var defaultRotationFileSize: UInt64 = 1024 * 1024 * 1024 /* 1GB */
    
    #if os(macOS)
    static var defaultBufferSize: UInt64 = 100 * 1024 * 1024 /* 100MB */
    #else
    static var defaultBufferSize: UInt64 = 1 * 1024 * 1024 /* 1MB <- smaller because file provider memory limits are small */
    #endif
}

private extension String {
    static var dataHeaderField: String { "DAT" }
    static var typeHeaderField: String { "TYP" }
    static var pathHeaderField: String { "PAT" }
    
    static var logFileExtension: String { ".log" }
    static var swapFileExtension: String { ".swap" }
    static var defaultLogFileName: String { "logs.log" }
}

// MARK: - Read operations

public extension PDFileManager {

    static func readCompressedFile(at url: URL) throws -> Data? {
        guard let filePath = FilePath(url) else {
            throw PDFileManagerError.urlIsNotAFilePath
        }
        return try readCompressedFile(at: filePath)
    }
    
    internal static func readCompressedFile(at filePath: FilePath) throws -> Data? {
        let (decodeStream, closeStreams) = try createReadStreamsStructure(filePath: filePath)
        defer { closeStreams() }
        
        guard
            let decodeHeader = try? decodeStream.readHeader(),
            let datField = decodeHeader.field(forKey: ArchiveHeader.FieldKey(.dataHeaderField)),
            case let .blob(key, size, _) = datField
        else {
            throw PDFileManagerError.cannotReadArchiveFile
        }

        guard size != 0 else { return nil }
        
        let rawBufferPtr = UnsafeMutableRawBufferPointer.allocate(byteCount: Int(size),
                                                                  alignment: MemoryLayout<Int8>.alignment)
        
        guard let baseAddress = rawBufferPtr.baseAddress else {
            throw PDFileManagerError.cannotReadArchiveFile
        }
        
        try decodeStream.readBlob(key: key, into: rawBufferPtr)
        
        let data = Data(bytesNoCopy: baseAddress, count: Int(size), deallocator: .custom { _, _ in
            rawBufferPtr.deallocate()
        })
        return data
    }
    
    private static func createReadStreamsStructure(filePath: FilePath) throws -> (ArchiveStream, () -> Void) {
        guard let readFileStream = ArchiveByteStream.fileStream(
            path: filePath, mode: .readOnly, options: [], permissions: filePermissions
        ) else {
            throw PDFileManagerError.cannotReadArchiveFile
        }
        
        guard let decompressStream = ArchiveByteStream.decompressionStream(readingFrom: readFileStream)
        else {
            closeStreamNotDeallocatingOnError(stream: readFileStream, label: "readFileStream")
            throw PDFileManagerError.cannotReadArchiveFile
        }
        
        guard let decodeStream = ArchiveStream.decodeStream(readingFrom: decompressStream)
        else {
            closeStreamNotDeallocatingOnError(stream: decompressStream, label: "decompressStream")
            closeStreamNotDeallocatingOnError(stream: readFileStream, label: "readFileStream")
            throw PDFileManagerError.cannotReadArchiveFile
        }
        
        return (decodeStream, {
            closeStreamNotDeallocatingOnError(stream: decodeStream, label: "decodeStream")
            closeStreamNotDeallocatingOnError(stream: decompressStream, label: "decompressStream")
            closeStreamNotDeallocatingOnError(stream: readFileStream, label: "readFileStream")
        })
    }
}

// MARK: - Write

public extension PDFileManager {
    
    private static func writeFileContentsToNewCompressedFile(source sourceFilePath: FilePath,
                                                             compressedFileName: String,
                                                             compressedFileType: ArchiveHeader.EntryType,
                                                             archivePath destinationFilePath: FilePath,
                                                             using fileManager: FileManager) throws {

        guard let sourceFileSize = try fileManager.attributesOfItem(atPath: sourceFilePath.string)[.size] as? UInt64
        else {
            throw PDFileManagerError.cannotGetFileSize
        }
        
        guard let sourceStream = ArchiveByteStream.fileStream(
            path: sourceFilePath, mode: .readOnly, options: [], permissions: filePermissions
        ) else {
            throw PDFileManagerError.cannotReadFile
        }
        defer { closeStreamNotDeallocatingOnError(stream: sourceStream, label: "sourceStream") }
        
        let swapFilePath = FilePath(destinationFilePath.string.appending(String.swapFileExtension))
        
        guard let writeFileStream = ArchiveByteStream.fileStream(
            path: swapFilePath, mode: .writeOnly, options: [.create, .truncate], permissions: filePermissions
        ) else {
            throw PDFileManagerError.cannotWriteToArchiveFile
        }
        defer { closeStreamNotDeallocatingOnError(stream: writeFileStream, label: "writeFileStream") }
        
        guard let compressStream = ArchiveByteStream.compressionStream(using: compressionAlgorithm,
                                                                       writingTo: writeFileStream)
        else {
            throw PDFileManagerError.cannotWriteToArchiveFile
        }
        defer { closeStreamNotDeallocatingOnError(stream: compressStream, label: "compressStream") }
        
        guard let encodeStream = ArchiveStream.encodeStream(writingTo: compressStream)
        else {
            throw PDFileManagerError.cannotWriteToArchiveFile
        }
        defer { closeStreamNotDeallocatingOnError(stream: encodeStream, label: "encodeStream") }
        
        let header = ArchiveHeader()
        header.append(.string(key: ArchiveHeader.FieldKey(.pathHeaderField), value: compressedFileName))
        header.append(.uint(key: ArchiveHeader.FieldKey(.typeHeaderField), value: UInt64(compressedFileType.rawValue)))
        header.append(.blob(key: ArchiveHeader.FieldKey(.dataHeaderField), size: sourceFileSize))
        
        do {
            try encodeStream.writeHeader(header)
            try passData(ofSize: sourceFileSize, from: sourceStream, to: encodeStream, maxBufferSize: defaultBufferSize)
            try removeSwapFile(swapFilePath: swapFilePath, destinationFilePath: destinationFilePath, using: fileManager)
        } catch {
            throw PDFileManagerError.cannotWriteToArchiveFile
        }
    }
    
    private static func createWriteStreamsStructure(filePath: FilePath) throws -> (ArchiveStream, () -> Void) {
        
        guard let writeFileStream = ArchiveByteStream.fileStream(
            path: filePath, mode: .writeOnly, options: [.create, .truncate], permissions: filePermissions
        ) else {
            throw PDFileManagerError.cannotWriteToArchiveFile
        }
        
        guard let compressStream = ArchiveByteStream.compressionStream(using: compressionAlgorithm,
                                                                       writingTo: writeFileStream)
        else {
            closeStreamNotDeallocatingOnError(stream: writeFileStream, label: "writeFileStream")
            throw PDFileManagerError.cannotWriteToArchiveFile
        }
        
        guard let encodeStream = ArchiveStream.encodeStream(writingTo: compressStream)
        else {
            closeStreamNotDeallocatingOnError(stream: compressStream, label: "compressStream")
            closeStreamNotDeallocatingOnError(stream: writeFileStream, label: "writeFileStream")
            throw PDFileManagerError.cannotWriteToArchiveFile
        }
        
        return (encodeStream, {
            closeStreamNotDeallocatingOnError(stream: encodeStream, label: "encodeStream")
            closeStreamNotDeallocatingOnError(stream: compressStream, label: "compressStream")
            closeStreamNotDeallocatingOnError(stream: writeFileStream, label: "writeFileStream")
        })
    }
}

// MARK: - Pass data from one place to another

public extension PDFileManager {
    
    private static func passData(
        ofSize size: UInt64, from decodeStream: ArchiveStream, to encodeStream: ArchiveStream, maxBufferSize: UInt64
    ) throws {
        // size calculation, as follows:
        // * if size is smaller or equal to maxBufferSize, allocate size and do the rewrite
        // * if size is larger than maxBufferSize
        //   * calculate the quotient and reminder of size / max_size
        //   * allocate two buffers: one with maxBufferSize and second with reminder
        //   * perform the read/write using the max_size, quotient times
        //   * perform the final read/write using the reminder, once
        let rawBufferPtr: UnsafeMutableRawBufferPointer
        let numerOfWritesInTheLoop: Int
        let isSecondBufferNeeded: Bool
        let secondBufferSize: Int // ignored if isSecondBufferNeeded == false
        
        if size <= maxBufferSize {
            rawBufferPtr = UnsafeMutableRawBufferPointer.allocate(byteCount: Int(size),
                                                                  alignment: MemoryLayout<Int8>.alignment)
            numerOfWritesInTheLoop = 1
            isSecondBufferNeeded = false
            secondBufferSize = 0
        } else {
            rawBufferPtr = UnsafeMutableRawBufferPointer.allocate(byteCount: Int(maxBufferSize),
                                                                  alignment: MemoryLayout<Int8>.alignment)
            numerOfWritesInTheLoop = Int(size / maxBufferSize)
            secondBufferSize = Int(size % maxBufferSize)
            isSecondBufferNeeded = secondBufferSize != 0
        }
        defer { rawBufferPtr.deallocate() }
        
        for _ in 1...numerOfWritesInTheLoop {
            try decodeStream.readBlob(key: .init(.dataHeaderField), into: rawBufferPtr)
            try encodeStream.writeBlob(key: .init(.dataHeaderField), from: UnsafeRawBufferPointer(rawBufferPtr))
        }
        
        if isSecondBufferNeeded {
            let secondBufferPtr = UnsafeMutableRawBufferPointer.allocate(byteCount: Int(secondBufferSize),
                                                                         alignment: MemoryLayout<Int8>.alignment)
            defer { secondBufferPtr.deallocate() }
            try decodeStream.readBlob(key: .init(.dataHeaderField), into: secondBufferPtr)
            try encodeStream.writeBlob(key: .init(.dataHeaderField), from: UnsafeRawBufferPointer(secondBufferPtr))
        }
    }
    
    private static func passData(
        ofSize size: UInt64, from fileStream: ArchiveByteStream, to encodeStream: ArchiveStream, maxBufferSize: UInt64
    ) throws {
        // size calculation, as follows:
        // * if size is smaller or equal to maxBufferSize, allocate size and do the rewrite
        // * if size is larger than maxBufferSize
        //   * calculate the quotient and reminder of size / max_size
        //   * allocate two buffers: one with maxBufferSize and second with reminder
        //   * perform the read/write using the max_size, quotient times
        //   * perform the final read/write using the reminder, once
        let rawBufferPtr: UnsafeMutableRawBufferPointer
        let numerOfWritesInTheLoop: Int
        let isSecondBufferNeeded: Bool
        let secondBufferSize: Int // ignored if isSecondBufferNeeded == false
        
        if size <= maxBufferSize {
            rawBufferPtr = UnsafeMutableRawBufferPointer.allocate(byteCount: Int(size),
                                                                  alignment: MemoryLayout<Int8>.alignment)
            numerOfWritesInTheLoop = 1
            isSecondBufferNeeded = false
            secondBufferSize = 0
        } else {
            rawBufferPtr = UnsafeMutableRawBufferPointer.allocate(byteCount: Int(maxBufferSize),
                                                                  alignment: MemoryLayout<Int8>.alignment)
            numerOfWritesInTheLoop = Int(size / maxBufferSize)
            secondBufferSize = Int(size % maxBufferSize)
            isSecondBufferNeeded = secondBufferSize != 0
        }
        
        for _ in 1...numerOfWritesInTheLoop {
            let readBytes = try fileStream.read(into: rawBufferPtr)
            try encodeStream.writeBlob(key: .init(.dataHeaderField), from: UnsafeRawBufferPointer(rawBufferPtr))
            assert(readBytes == rawBufferPtr.count)
        }
        
        rawBufferPtr.deallocate()
        
        if isSecondBufferNeeded {
            let secondBufferPtr = UnsafeMutableRawBufferPointer.allocate(byteCount: Int(secondBufferSize),
                                                                         alignment: MemoryLayout<Int8>.alignment)
            let readBytes = try fileStream.read(into: secondBufferPtr)
            try encodeStream.writeBlob(key: .init(.dataHeaderField), from: UnsafeRawBufferPointer(secondBufferPtr))
            assert(readBytes == secondBufferPtr.count)
            secondBufferPtr.deallocate()
        }
    }
}

// MARK: - Append

public extension PDFileManager {
    
    private static func logsFileName(_ destinationFilePath: FilePath) -> String {
        return destinationFilePath.lastComponent?.stem.appending(String.logFileExtension) ?? .defaultLogFileName
    }
    
    private static var logsFileType: ArchiveHeader.EntryType { .regularFile }
    
    private static let rotateFileDateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "YYMMddHHmmssSSS"
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        return dateFormatter
    }()
    
    enum RotationStrategy {
        case doNotRotate
        case rotateIfUncompressedFileSizeLargerThan(UInt64) // size in bytes
        case alwaysRotate
    }
    
    static func appendLogsWithCompressionIfEnabled(from sourceFileURL: URL, to destinationFileURL: URL, compressionDisabled: () -> Bool) throws {
        if compressionDisabled() {
            try PDFileManager.appendFileContents(from: sourceFileURL, to: destinationFileURL)
        } else {
            // on macOS, we use a compressed file to reduce the size of the files on disk,
            // rotating the archive if the uncompressed size is over 1GB
            let compressedDestinationFileURL = destinationFileURL.deletingPathExtension().appendingPathExtension("aar")
            try PDFileManager.appendFileContentsToCompressedFile(from: sourceFileURL, to: compressedDestinationFileURL)
        }
    }
    
    static func appendFileContentsToCompressedFile(
        from sourceURL: URL,
        to destinationURL: URL,
        compressedFileName: String? = nil,
        compressedFileType: ArchiveHeader.EntryType? = nil,
        using fileManager: FileManager = .default,
        maxBufferSize: UInt64 = defaultBufferSize,
        rotationStrategy: RotationStrategy = .rotateIfUncompressedFileSizeLargerThan(defaultRotationFileSize)
    ) throws {
        
        guard
            let destinationFilePath = FilePath(destinationURL),
            let sourceFilePath = FilePath(sourceURL)
        else {
            throw PDFileManagerError.urlIsNotAFilePath
        }
        
        let compressedFileName = compressedFileName ?? logsFileName(destinationFilePath)
        let compressedFileType = compressedFileType ?? logsFileType
        
        func writeToNewFile() throws {
            try writeFileContentsToNewCompressedFile(
                source: sourceFilePath,
                compressedFileName: compressedFileName,
                compressedFileType: compressedFileType,
                archivePath: destinationFilePath,
                using: fileManager
            )
        }
        
        guard let destinationStreamStructure = try? createReadStreamsStructure(filePath: destinationFilePath)
        else {
            // there is no destination file, so even if we want to append, we cannot
            try writeToNewFile()
            return
        }
        
        let (decodeStream, closeStreams) = destinationStreamStructure
        guard let decodeHeader = try? decodeStream.readHeader(),
              case .blob(_, let size, _)? = decodeHeader.field(forKey: .init(.dataHeaderField))
        else {
            // This means that the destination archive file is corrupted. We overwrite it.
            // The logs from the corrupted file are, unfortunatelly, lost.
            // This scenario should be very rare, because we use a swap file whenever we write to logs archive.
            Log.error("Corrupted logs archive. Overwriting the existing file", domain: .storage)
            closeStreams()
            try writeToNewFile()
            return
        }
        
        func appendToExistingFile() throws {
            try appendFileContentsToAlreadyExistingCompressedFile(
                source: sourceFilePath,
                compressedFileName: compressedFileName,
                compressedFileType: compressedFileType,
                destinationStream: (decodeStream, closeStreams, size),
                archivePath: destinationFilePath,
                using: fileManager,
                dataRewriteMaxBufferSize: maxBufferSize
            )
        }
        
        func doNotRotate() throws {
            do {
                try appendToExistingFile()
            } catch PDFileManagerError.cannotPassDataFromArchiveToArchive {
                // This means that the destination archive file is corrupted. We overwrite it.
                // The logs from the corrupted file are, unfortunatelly, lost.
                // This scenario should be very rare, because we use a swap file whenever we write to logs archive.
                Log.error("Corrupted logs archive. Overwriting the existing file", domain: .storage)
                closeStreams()
                try writeToNewFile()
            }
        }
            
        switch rotationStrategy {
        case .doNotRotate:
            try doNotRotate()
            
        case .rotateIfUncompressedFileSizeLargerThan(let maxSize) where size < maxSize:
            // rotation not needed, just append
            try doNotRotate()
        
        case .rotateIfUncompressedFileSizeLargerThan, .alwaysRotate:
            
            let originalFileNameStem = destinationURL.deletingPathExtension().lastPathComponent
            let originalFileExtension = destinationURL.pathExtension
            
            let timePostfix = rotateFileDateFormatter.string(from: Date.now)
            let rotatedFileURL = destinationURL.deletingLastPathComponent()
                .appendingPathComponent(originalFileNameStem + "-" + timePostfix, conformingTo: .log)
                .appendingPathExtension(originalFileExtension)
            do {
                // close streams before moving
                closeStreams()
                try fileManager.moveItem(at: destinationURL, to: rotatedFileURL)
            } catch {
                // if you cannot rotate, force appending to at least have the logs somewhere
                try appendFileContentsToCompressedFile(
                    from: sourceURL,
                    to: destinationURL,
                    compressedFileName: compressedFileName,
                    compressedFileType: compressedFileType,
                    using: fileManager,
                    maxBufferSize: maxBufferSize,
                    rotationStrategy: .doNotRotate
                )
                return
            }
            
            try writeToNewFile()
        }
    }
    
    // swiftlint:disable:next function_parameter_count
    private static func appendFileContentsToAlreadyExistingCompressedFile(
        source sourceFilePath: FilePath,
        compressedFileName: String,
        compressedFileType: ArchiveHeader.EntryType,
        destinationStream: (ArchiveStream, () -> Void, UInt64),
        archivePath destinationFilePath: FilePath,
        using fileManager: FileManager,
        dataRewriteMaxBufferSize: UInt64
    ) throws {
        
        let (decodeStream, closeReadStreams, size) = destinationStream
        defer { closeReadStreams() }
        
        guard let sourceFileSize = try fileManager.attributesOfItem(atPath: sourceFilePath.string)[.size] as? UInt64
        else {
            throw PDFileManagerError.cannotGetFileSize
        }
        
        guard let sourceStream = ArchiveByteStream.fileStream(
            path: sourceFilePath, mode: .readOnly, options: [], permissions: filePermissions
        ) else {
            throw PDFileManagerError.cannotReadFile
        }
        defer { closeStreamNotDeallocatingOnError(stream: sourceStream, label: "sourceStream") }
        
        let swapFilePath = FilePath(destinationFilePath.string.appending(String.swapFileExtension))
        
        let (encodeStream, closeWriteStreams) = try createWriteStreamsStructure(filePath: swapFilePath)
        defer { closeWriteStreams() }
        
        let encodeHeader = ArchiveHeader()
        encodeHeader.append(.string(key: ArchiveHeader.FieldKey(.pathHeaderField), value: compressedFileName))
        encodeHeader.append(.uint(key: ArchiveHeader.FieldKey(.typeHeaderField), value: UInt64(compressedFileType.rawValue)))
        encodeHeader.append(.blob(key: ArchiveHeader.FieldKey(.dataHeaderField), size: size + sourceFileSize))
        
        try encodeStream.writeHeader(encodeHeader)
        do {
            try passData(ofSize: size, from: decodeStream, to: encodeStream, maxBufferSize: dataRewriteMaxBufferSize)
        } catch {
            throw PDFileManagerError.cannotPassDataFromArchiveToArchive
        }
        try passData(ofSize: sourceFileSize, from: sourceStream, to: encodeStream, maxBufferSize: dataRewriteMaxBufferSize)
        try removeSwapFile(swapFilePath: swapFilePath, destinationFilePath: destinationFilePath, using: fileManager)
    }
    
    private static func removeSwapFile(swapFilePath: FilePath,
                                       destinationFilePath: FilePath,
                                       using fileManager: FileManager) throws {
        let swapFileURL = URL(fileURLWithPath: swapFilePath.string)
        let destinationFileURL = URL(fileURLWithPath: destinationFilePath.string)
        _ = try fileManager.replaceItemAt(destinationFileURL, withItemAt: swapFileURL)
    }
}

// MARK: - Directory archiving and unarchiving

extension PDFileManager {
    
    public static func archiveContentsOfDirectory(_ directoryURL: URL,
                                                  into archiveURL: URL,
                                                  using fileManager: FileManager = .default) throws {

        guard
            let directoryPath = FilePath(directoryURL),
            let archiveFilePath = FilePath(archiveURL),
            let archiveFileName = archiveFilePath.lastComponent
        else {
            throw PDFileManagerError.urlIsNotAFilePath
        }
        
        let (encodeStream, closeStreams) = try createWriteStreamsStructure(filePath: archiveFilePath)
        defer { closeStreams() }
        
        // this fieldkeyset list is taken directly from the documentation, please refine it if needed
        guard let keySet = ArchiveHeader.FieldKeySet("TYP,PAT,LNK,DEV,DAT,UID,GID,MOD,FLG,MTM,BTM,CTM")
        else {
            throw PDFileManagerError.cannotWriteToArchiveFile
        }

        try encodeStream.writeDirectoryContents(
            archiveFrom: directoryPath, keySet: keySet, selectUsing: { entry, path, data in
                guard path.string != archiveFileName.string else {
                    return .skip
                }
                return .ok
            }
        )
    }
    
    public static func unarchiveDirectory(from archiveURL: URL,
                                          into directoryURL: URL,
                                          using fileManager: FileManager = .default) throws {
        
        guard let archiveFilePath = FilePath(archiveURL), let directoryPath = FilePath(directoryURL)
        else {
            throw PDFileManagerError.urlIsNotAFilePath
        }
        
        let (decodeStream, closeStreams) = try createReadStreamsStructure(filePath: archiveFilePath)
        
        try fileManager.createDirectory(atPath: directoryPath.string, withIntermediateDirectories: true)
        
        guard let extractStream = ArchiveStream.extractStream(
            extractingTo: directoryPath, flags: [.ignoreOperationNotPermitted]
        ) else {
            closeStreams()
            throw PDFileManagerError.cannotWriteFile
        }
        
        let processedBytes = try ArchiveStream.process(readingFrom: decodeStream, writingTo: extractStream)
        
        closeStreamNotDeallocatingOnError(stream: extractStream, label: "extractStream")
        closeStreams()
        
        guard processedBytes != .zero
        else {
            throw PDFileManagerError.cannotWriteFile
        }
    }
}

// MARK: - Helper methods

/*
 
 The methods here wrap the stream instance into the RetainCycleBox before calling the `close` method.
 If the `close` method fails, the stream instance is NEVER DEALLOCATED, LEAKED ON PURPOSE.
 The rationale for that very unfortunate error handling necessity is as follows:
 
 If closing the stream fails, the system will throw a runtime error on the stream deallocation, crashing the app.
 Also, there's no easy recovery path from the stream close failure.
 
 The main known scenario in which closing the stream might fail is a corrupted compressed file.
 However, we do guard against the compressed file corruption.
 Whenever we write the compressed stream, we write into a temporary swap file.
 Only once writing into the temporary swap file successfully finishes, we replace the original file with it.
 We also have additional higher-level mechanism in which we overwrite the corrupted logs file if the corruption ever happens.

 So, we are pretty confident the stream close failure should be very rare.
 However, just to avoid crashing the app in this very rare case, we choose to leak the stream instance.
 
 */
public extension PDFileManager {
    
    static func closeStreamNotDeallocatingOnError(stream: ArchiveStream, label: String) {
        do {
            let retainBox = RetainCycleBox(value: stream)
            try stream.close()
            retainBox.breakRetainCycle()
        } catch {
            Log.error("Stream closing error: \(label)", error: error, domain: .diagnostics)
        }
    }
    
    static func closeStreamNotDeallocatingOnError(stream: ArchiveByteStream, label: String) {
        do {
            let retainBox = RetainCycleBox(value: stream)
            try stream.close()
            retainBox.breakRetainCycle()
        } catch {
            Log.error("Stream closing error: \(label)", error: error, domain: .diagnostics)
        }
    }
}

#endif
