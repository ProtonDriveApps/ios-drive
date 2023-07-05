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
import FileProvider

extension Tower {

    // MARK: - Resolve conflict

    func resolveConflict(between item: NSFileProviderItem, with url: URL?, and conflictingNode: Node?, applying action: ResolutionAction) async throws -> NSFileProviderItem {
        switch action {
        case .ignore:
            // if the conflict is direct, then `conflictingNode` will be the remote version of item,
            // however in the case of indirect conflicts, will represent a different node
            guard let remoteNode = node(itemIdentifier: item.itemIdentifier) else {
                guard let conflictingNode else {
                    return item
                }
                return NodeItem(node: conflictingNode)
            }
            return NodeItem(node: remoteNode)

        case .recreate:
            guard let parent = parentFolder(of: item) else {
                throw Errors.parentNotFound
            }
            if item.isFolder {
                let recreatedFolder = try await createFolder(named: item.filename, under: parent)
                return NodeItem(node: recreatedFolder)
            } else {
                let recreatedFile = try await createFile(item: item, with: url, under: parent)
                return (NodeItem(node: recreatedFile))
            }

        case .createWithUniqueSuffixInConflictsFolder:
            let conflictsFolder = try rootFolder()
            let newItem = NodeItem(item: item, filename: item.filename.conflictNodeName)
            if item.isFolder {
                let createdNode = try await createFolder(named: newItem.filename, under: conflictsFolder)
                return NodeItem(node: createdNode)
            } else {
                let file = try await createFile(item: newItem, with: url, under: conflictsFolder)
                return (NodeItem(node: file))
            }

        case .createWithUniqueSuffix:
            let newItem = NodeItem(item: item, filename: item.filename.conflictNodeName)
            guard let parent = parentFolder(of: item) else {
                throw Errors.parentNotFound
            }
            if item.isFolder {
                let createdNode = try await createFolder(named: newItem.filename, under: parent)
                return NodeItem(node: createdNode)
            } else {
                let createdFile = try await createFile(item: newItem, with: url, under: parent)
                return (NodeItem(node: createdFile))
            }
            
        case .renameWithUniqueSuffix:
            let newItem = NodeItem(item: item, filename: item.filename.conflictNodeName)
            guard let nodeIdentifier = nodeIdentifier(for: newItem.itemIdentifier) else {
                assertionFailure("Could not create nodeIdentifier from newItem.itemIdentifier: \(newItem.itemIdentifier.debugDescription)")
                throw NSFileProviderError(.noSuchItem)
            }

            _ = try await rename(node: nodeIdentifier, cleartextName: newItem.filename)

            return newItem
            
        case .moveAndRenameWithUniqueSuffix:
            let newItem = NodeItem(item: item, filename: item.filename.conflictNodeName)
            guard let nodeIdentifier = nodeIdentifier(for: newItem.itemIdentifier) else {
                assertionFailure("Could not create nodeIdentifier from newItem.itemIdentifier: \(newItem.itemIdentifier.debugDescription)")
                throw NSFileProviderError(.noSuchItem)
            }

            guard let newParent = parentFolder(of: newItem) else {
                throw Errors.parentNotFound
            }
            
            _ = try await move(nodeID: nodeIdentifier, under: newParent, withNewName: newItem.filename)

            return newItem
        }
    }

    private func newFileItemFrom(node: Conflicting) -> NSFileProviderItem? {
        guard let file = node as? File else {
            return nil
        }
        return NodeItem(node: file)
    }

    private func createFile(item: NSFileProviderItem, with url: URL?, under parent: Folder) async throws -> File {
        guard let copy = self.prepare(forUpload: item, from: url) else {
            throw Errors.emptyUrlForFileUpload
        }

        defer { try? FileManager.default.removeItem(at: copy.deletingLastPathComponent()) }

        // Fetch the draft if it already exists otherwise create a new one
        let draft: File
        if let existingDraft = self.draft(for: item) {
            draft = existingDraft
        } else {
            draft = try fileImporter.importFile(from: copy, to: parent, with: item.itemIdentifier.rawValue)
        }
        return try await fileUploader.upload(draft)
    }

    private func prepare(forUpload itemTemplate: NSFileProviderItem, from url: URL?) -> URL? {
        guard let url = url else { return nil }
        // copy file from system temporary location to app temporary location so it will have correct mime and name
        // TODO: inject mime and name directly into Uploader
        let copyParent = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
        let copy = copyParent.appendingPathComponent(itemTemplate.filename)
        try? FileManager.default.removeItem(atPath: copyParent.path)
        try? FileManager.default.createDirectory(at: copyParent, withIntermediateDirectories: true, attributes: nil)
        try? FileManager.default.copyItem(at: url, to: copy)
        return copy
    }

}
