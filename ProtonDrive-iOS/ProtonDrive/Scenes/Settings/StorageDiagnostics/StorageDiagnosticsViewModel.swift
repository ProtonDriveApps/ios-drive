// Copyright (c) 2025 Proton AG
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
import FileProvider
import PDCore

final class StorageDiagnosticsViewModel: ObservableObject {
    @Published private(set) var isAnalyzing = true
    @ThreadSafe private var seenInodes = Set<UInt64>()
    private let coordinator: StorageDiagnosticsCoordinator
    private weak var storageManager: StorageManager?
    private(set) var sections: [Section] = []
    private lazy var formatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file   // matches Finder / iPhone Storage
        formatter.allowsNonnumericFormatting = false
        return formatter
    }()

    init(storageManager: StorageManager, coordinator: StorageDiagnosticsCoordinator) {
        self.storageManager = storageManager
        self.coordinator = coordinator
    }

    func analyze() {
        Task.detached {
            self.sections = [
                self.analyzePermanentData(),
                self.analyzeTemporaryData(),
                self.analyzeDatabase()
            ]
            await MainActor.run {
                self.isAnalyzing = false
            }
        }
    }

    func formatted(size: UInt64) -> String {
        return formatter.string(fromByteCount: Int64(size))
    }
}

extension StorageDiagnosticsViewModel {
    private func getVolumeIds() -> (String, String)? {
        guard
            let storageManager,
            let volumeIDs = try? storageManager.getVolumeIDs(in: storageManager.backgroundContext),
            let photoVolumeID = volumeIDs.photo
        else { return nil }
        return (volumeIDs.main, photoVolumeID)
    }

    private func analyzePermanentData() -> Section {
        let url = PDFileManager.permanentDataDirectory
            .appending(path: PDFileManager.getUserID())
        return Section(
            title: "Permanent folder",
            items: [
                .init(title: "usage", size: realStorageUsageFor(folderURL: url)),
            ]
        )
    }

    private func analyzeTemporaryData() -> Section {
        let legacyDownloadsSizeInBytes = realStorageUsageFor(folderURL: PDFileManager.cypherBlocksCacheDirectory)
        let sdkDownloadsSizeInBytes = realStorageUsageFor(folderURL: PDFileManager.sdkDownloadsDirectory)

        let userDirectory = PDFileManager.appGroupTemporaryDirectory.appending(path: PDFileManager.getUserID())
        let decryptedSizeInBytes = realStorageUsageFor(folderURL: userDirectory)
        var fpSizeInBytes: UInt64?

        if let fileProviderURL = PDFileManager.getFileProviderStorageURL() {
            fpSizeInBytes = realStorageUsageFor(folderURL: fileProviderURL)
        }

        return Section(
            title: "Temporary folder",
            items: [
                .init(title: "Decrypted files/ thumbnails", size: decryptedSizeInBytes),
                .init(title: "Downloading files", size: legacyDownloadsSizeInBytes + sdkDownloadsSizeInBytes),
                .init(title: "Uploading files", size: realStorageUsageFor(folderURL: PDFileManager.cleartextCacheDirectory)),
                .init(title: "File provider", size: fpSizeInBytes)
            ],
            clearAction: {
                Task { @MainActor in
                    self.presentClearTempFolderAlert()
                }
            }
        )
    }

    private func analyzeDatabase() -> Section {
        let baseURL = PDFileManager.appGroupTemporaryDirectory.deletingLastPathComponent()
        let metadataSize = [
            baseURL.appending(path: "Metadata.sqlite"),
            baseURL.appending(path: "Metadata.sqlite-shm"),
            baseURL.appending(path: "Metadata.sqlite-wal")
        ].reduce(0, { $0 + realStorageUsageFor(fileURL: $1) })
        let eventSize = [
            baseURL.appending(path: "EventStorageModel.sqlite"),
            baseURL.appending(path: "EventStorageModel.sqlite-shm"),
            baseURL.appending(path: "EventStorageModel.sqlite-wal")
        ].reduce(0, { $0 + realStorageUsageFor(fileURL: $1) })

        return Section(
            title: "Database",
            items: [
                .init(title: "metadata", size: metadataSize),
                .init(title: "event", size: eventSize),
            ]
        )
    }

    private func enumerator(at folderURL: URL) -> FileManager.DirectoryEnumerator? {
        FileManager.default.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.fileSizeKey, .fileResourceIdentifierKey, .isRegularFileKey],
            options: [],
            errorHandler: nil
        )
    }

    private func presentClearTempFolderAlert() {
        coordinator.presentClearTempFolderAlert {
            do {
                try FileManager.default.removeItem(at: PDFileManager.appGroupTemporaryDirectory)
                Task { @MainActor in
                    self.seenInodes = []
                    // Spinner appear event triggers analyze function
                    self.isAnalyzing = true
                }
            } catch {
                Log.error("Clear temp folder failed", error: error, domain: .application)
            }
        }
    }

    /// - Returns: bytes
    private func realStorageUsageFor(folderURL: URL) -> UInt64 {
        var totalSize: UInt64 = 0

        guard let enumerator = enumerator(at: folderURL) else { return totalSize }

        for case let fileURL as URL in enumerator {
            totalSize += realStorageUsageFor(fileURL: fileURL)
        }

        return totalSize
    }

    private func realStorageUsageFor(fileURL: URL) -> UInt64 {
        do {
            let keys: Set<URLResourceKey> = [.fileSizeKey, .fileResourceIdentifierKey, .isRegularFileKey]
            let resourceValues = try fileURL.resourceValues(forKeys: keys)

            guard
                fileURL.lastPathComponent != ".DS_Store",
                resourceValues.isRegularFile == true,
                let fileSize = resourceValues.fileSize,
                let fileID = resourceValues.fileResourceIdentifier as? NSData
            else { return 0 }

            // Convert NSData (fileResourceIdentifier) to a hashable identifier
            let inode = fileID.hashValue

            // Only count if we haven't seen this inode before
            if !seenInodes.contains(UInt64(inode)) {
                seenInodes.insert(UInt64(inode))
                return UInt64(fileSize)
            }
        } catch {
            Log.error("Failed to get size of \(fileURL)", error: error, domain: .application)
        }
        return 0
    }
}

extension StorageDiagnosticsViewModel {
    final class Section: Identifiable {
        let title: String
        let items: [StorageInfo]
        let clearAction: (() -> Void)?
        var totalSize: UInt64 { items.reduce(0) { $0 + $1.size } }

        init(title: String, items: [StorageInfo?], clearAction: (() -> Void)? = nil) {
            self.title = title
            self.items = items.compactMap { $0 }
            self.clearAction = clearAction
        }
    }

    struct StorageInfo: Identifiable {
        let id: UUID = UUID()
        let title: String
        let size: UInt64

        init?(title: String, size: UInt64?) {
            guard let size else {
                return nil
            }
            self.title = title
            self.size = size
        }
    }
}
