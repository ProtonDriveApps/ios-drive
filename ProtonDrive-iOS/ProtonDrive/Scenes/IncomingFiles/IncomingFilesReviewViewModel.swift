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
import PDCoreIOS
import PDLocalization

@MainActor
final class IncomingFilesReviewViewModel: ObservableObject {
    @Published private(set) var editingFileID: URL?
    @Published private(set) var isUploading = false
    @Published private(set) var listedFiles: [ListedIncomingFile] = []
    @Published private(set) var selectAllToken = 0
    @Published private(set) var selectedFolder: Folder
    @Published private(set) var thumbnails: [URL: Data] = [:]
    @Published var editingName = ""
    @Published var isShowingDestinationPicker = false

    let authenticatedContainer: AuthenticatedDependencyContainer
    let rootNodeID: NodeIdentifier
    private let thumbnailProvider: SynchronizedThumbnailProviderProtocol
    private var tower: Tower { authenticatedContainer.tower }
    private let userMessageHandler = UserMessageHandler()
    private var thumbnailFailures = Set<URL>()
    private var thumbnailRequests: [URL: Task<Void, Never>] = [:]

    init(
        rootNodeID: NodeIdentifier,
        initialFolder: Folder,
        authenticatedContainer: AuthenticatedDependencyContainer,
        thumbnailProvider: SynchronizedThumbnailProviderProtocol = ThumbnailProviderFactory.defaultSynchronizedThumbnailProvider
    ) {
        self.rootNodeID = rootNodeID
        self.selectedFolder = initialFolder
        self.authenticatedContainer = authenticatedContainer
        self.thumbnailProvider = thumbnailProvider
    }

    var canSave: Bool {
        !isUploading && !listedFiles.isEmpty
    }

    var currentDestinationName: String {
        selectedFolder.isRoot ? Localization.menu_text_my_files : selectedFolder.decryptedName
    }

    func onAppear() {
        reloadListedFiles()
    }

    func cancel() {
        PDFileManager.cleanShareTempFolder()
    }

    func reloadListedFiles() {
        do {
            let urls = try FileManager.default.contentsOfDirectory(
                at: PDFileManager.shareTempFolderDirectory,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            )
            listedFiles = urls.compactMap { url in
                guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) != false else {
                    return nil
                }
                return ListedIncomingFile(url: url)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            pruneThumbnailCaches()
        } catch {
            Log.error("Failed to list share temp files", error: error, domain: .shareExtension)
            listedFiles = []
            thumbnails = [:]
            thumbnailFailures = []
            cancelAllThumbnailRequests()
        }
    }
    
    func update(selectedFolder: CoreDataFolder) {
        self.selectedFolder = selectedFolder
    }
}

// MARK: - Save
extension IncomingFilesReviewViewModel {
    func save(onDismiss: @escaping () -> Void) {
        guard commitEditingIfNeeded() else { return }
        isUploading = true
        Task {
            do {
                try await save()
            } catch {
                Log.error("Save incoming files failed", error: error, domain: .shareExtension)
            }

            let deeplink = await makeDeepLink() ?? Deeplink()
            await MainActor.run {
                self.isUploading = false
                onDismiss()
                let notify = DeepLinkNotification(menuDestination: .myFiles, tab: .files, link: deeplink)
                NotificationCenter.default.post(name: .deepLink, object: notify)
            }
        }
    }
    
    func save() async throws {
        let copiedURLs = moveSharedFiles()
        let importedFiles = try importUrls(copiedURLs, to: selectedFolder)
        upload(files: importedFiles, to: selectedFolder)
    }
    
    // Move shared files from app group temp folder to app folder
    private func moveSharedFiles() -> [URL] {
        do {
            var copiedURLs: [URL] = []
            for file in listedFiles {
                let copyURL = PDFileManager.prepareUrlForFile(named: file.name)
                try FileManager.default.moveItem(at: file.url, to: copyURL)
                copiedURLs.append(copyURL)
            }
            return copiedURLs
        } catch {
            Log.error("Move shared file failed", error: error, domain: .shareExtension)
            PDFileManager.cleanShareTempFolder()
            return []
        }
    }

    private func importUrls(_ urls: [URL], to currentFolder: CoreDataFolder) throws -> [CoreDataFile] {
        var importedFiles: [CoreDataFile] = []
        for url in urls {
            let newFile = try tower.fileImporter.importFile(from: url, to: currentFolder, with: nil)
            importedFiles.append(newFile)
        }
        return importedFiles
    }

    private func upload(files: [CoreDataFile], to currentFolder: CoreDataFolder) {
        let sdkUploader = tower.sdkObjects.fileUploader
        Log.debug("Upload \(files.count) via SDK", domain: .shareExtension)
        // When the user shares photo backup diagnostics to PD
        // we refresh `My Files` and upload files at the same time
        // which can cause a Core Data sorting error
        // To prevent this issue, ensure the upload runs on the MainActor
        Task { @MainActor in
            do {
                try await withThrowingTaskGroup { group in
                    for file in files {
                        group.addTask {
                            _ = try await sdkUploader.upload(identifier: file.identifier.any())
                        }
                    }
                    try await group.waitForAll()
                }
            } catch {
                Log.error("Upload share file failed", error: error, domain: .shareExtension)
            }
        }
    }
    
    private func makeDeepLink() async -> Deeplink? {
        guard let context = selectedFolder.managedObjectContext else {
            Log.error("Make deeplink failed", error: nil, domain: .shareExtension)
            return nil
        }
        let objectID = selectedFolder.objectID
        do {
            return try await context.perform {
                let currentFolder: CoreDataFolder = try context.typedObject(with: objectID)
                var chain = currentFolder
                    .parentsChain()
                    .map(\.identifierWithinManagedObjectContext)
                chain.append(currentFolder.identifierWithinManagedObjectContext)
                let link = Deeplink()
                link.inject(chain)
                return link
            }
        } catch {
            Log.error("Make deeplink failed", error: error, domain: .shareExtension)
            return nil
        }
    }
}

// MARK: - Editing
extension IncomingFilesReviewViewModel {
    func beginEditing(_ listedFile: ListedIncomingFile) {
        guard commitEditingIfNeeded() else { return }
        editingFileID = listedFile.id
        editingName = listedFile.name
        selectAllToken += 1
    }

    @discardableResult
    func commitEditingIfNeeded() -> Bool {
        guard let editingFileID else { return true }
        guard let oldFile = listedFiles.first(where: { $0.id == editingFileID }) else {
            endEditing()
            return true
        }

        let newName = editingName
        defer { endEditing() }

        guard newName != oldFile.name else { return true }

        do {
            let validatedName = try newName.validateNodeName(validator: NameValidations.iosName)
            let parentURL = oldFile.url.deletingLastPathComponent()
            let newURL = parentURL.appendingPathComponent(validatedName)
            if newURL.path == oldFile.url.path {
                return true
            }
            guard !FileManager.default.fileExists(atPath: newURL.path) else {
                throw PlainMessageError(Localization.duplication_handler_view_subtitle(filename: validatedName))
            }
            try FileManager.default.moveItem(at: oldFile.url, to: newURL)
            reloadListedFiles()
            return true
        } catch {
            userMessageHandler.handleError(PlainMessageError(error.localizedDescription))
            return false
        }
    }
    
    private func endEditing() {
        editingFileID = nil
        editingName = ""
    }
}

// MARK: - Thumbnails
extension IncomingFilesReviewViewModel {
    func thumbnail(for listedFile: ListedIncomingFile) -> Data? {
        thumbnails[listedFile.id]
    }

    func requestThumbnail(for listedFile: ListedIncomingFile) {
        let url = listedFile.url
        guard
            thumbnails[url] == nil,
            thumbnailRequests[url] == nil,
            !thumbnailFailures.contains(url)
        else { return }

        let task = Task { [weak self] in
            guard let self else { return }
            let data = await self.thumbnailProvider.defaultThumbnailData(fileUrl: url, overrideMediaType: nil)
            guard !Task.isCancelled else { return }

            if let data {
                self.thumbnails[url] = data
            } else {
                self.thumbnailFailures.insert(url)
            }
            self.thumbnailRequests[url] = nil
        }
        thumbnailRequests[url] = task
    }
    
    private func pruneThumbnailCaches() {
        let validURLs = Set(listedFiles.map(\.id))

        thumbnails = thumbnails.filter { validURLs.contains($0.key) }
        thumbnailFailures = thumbnailFailures.filter { validURLs.contains($0) }

        let staleURLs = thumbnailRequests.keys.filter { !validURLs.contains($0) }
        for url in staleURLs {
            thumbnailRequests[url]?.cancel()
            thumbnailRequests[url] = nil
        }
    }

    private func cancelAllThumbnailRequests() {
        for task in thumbnailRequests.values {
            task.cancel()
        }
        thumbnailRequests.removeAll()
    }
}

struct ListedIncomingFile: Identifiable {
    let url: URL
    let name: String
    let size: Int64
    let icon: FileAssetName

    var id: URL { url }

    init(url: URL, fileTypeAsset: FileTypeAssetResolver = FileTypeAsset.shared) {
        self.url = url
        self.name = url.lastPathComponent
        self.size = Int64(url.fileSize ?? 0)
        self.icon = fileTypeAsset.getAsset(url.mimeType())
    }
}
