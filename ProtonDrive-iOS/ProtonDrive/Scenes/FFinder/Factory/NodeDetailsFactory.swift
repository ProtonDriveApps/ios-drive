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
import PDSDKCore
import PDLocalization
import UniformTypeIdentifiers
import PDUIComponents
import UIKit

struct NodeDetailsFactory {
    let tower: Tower

    func makeDetailsView(for node: NodeDTO) async -> UIViewController {
        let title = title(for: node)

        let viewModel = NNodeDetailsViewModel(
            title: title,
            nodeName: node.name,
            details: await makeDetails(node: node),
            qaDetails: await qaDetails(file: node)
        )
        let view = await NNodeDetailsView(vm: viewModel).embeddedInHostingController()
        return view
    }

    private func title(for node: NodeDTO) -> String {
        if node.isFolder {
            return Localization.folder_detail_title
        } else if node.isFile {
            return Localization.file_detail_title
        } else {
            assert(false, "Undefined node type")
            return Localization.file_detail_general_title
        }
    }

    private func makeDetails(node: NodeDTO) async -> [(key: String, value: String)] {
        var details: [(key: String, value: String)] = await folderDetails(folder: node)
        guard node.isFile else { return details }
        details.append((Localization.file_detail_extension, fileExtension(nodeName: node.name, mimeType: node.mimeType)))
        if !node.isProtonFile {
            details.append((Localization.file_detail_size, size(file: node)))
        }
        // TODO: finder-refactor, review highlight. it was `file.isNodeShared()`, a bit different from node.isShared
        let shareStatus = node.isShared ? Localization.file_detail_share_yes : Localization.file_detail_share_no
        details.append((Localization.file_detail_shared, shareStatus))
        return details
    }

    private func folderDetails(folder: NodeDTO) async -> [(key: String, value: String)] {
        [
            (Localization.file_detail_name, folder.name),
            (Localization.file_detail_uploaded_by, editorAddress(node: folder)),
            (Localization.file_detail_location, await path(node: folder)),
            (Localization.file_detail_modified, DateFormatter.shortRelative.string(from: folder.modificationDate))
        ]
    }

    private func qaDetails(file: NodeDTO) async -> [(key: String, value: String)]? {
        guard
            Constants.buildType.isQaOrBelow,
            file.isFile,
            let revision = file.activeRevision
        else { return nil }
        var size: String
        let extendedAttributes = await tower.storage.backgroundContextPool.performInContext { context in
            return file.extendedAttributes(performIn: context)
        }
        if let claimedSize = extendedAttributes.common?.size {
            size = ByteCountFormatter.storageSizeString(forByteCount: Int64(claimedSize) )
        } else {
            size = "-"
        }
        var details: [(key: String, value: String)] = [
            ("Key author", file.keyAuthor?.emailAddress ?? "-"),
            ("Name author", file.nameAuthor?.emailAddress ?? "-"),
            ("Content author", revision.contentAuthor?.emailAddress ?? "-"),
            ("MIME type", file.mimeType),
            ("Original size", size),
            ("SHA1", extendedAttributes.common?.digests?.sha1 ?? "-")
        ]
        details += makeExtendedAttributes(node: file, attributes: extendedAttributes)
        return details
    }

    private func editorAddress(node: NodeDTO) -> String {
        guard let signatureEmail = node.keyAuthor?.emailAddress, !signatureEmail.isEmpty else {
            return Localization.file_detail_uploaded_by_anonymous
        }
        guard let address = tower.sessionVault.getAddress(for: signatureEmail) else {
            return signatureEmail
        }
        if address.displayName.isEmpty {
            return "\(address.email)"
        } else {
            return "\(address.displayName)\n\(address.email)"
        }
    }

    private func path(node: NodeDTO) async -> String {
        await tower.storage.backgroundContextPool.performInContext { context in
            guard let coreDataNode: CoreDataNode = try? context.typedObject(with: node.objectID) else { return "↻" }
            var path = [coreDataNode.parentNode?.decryptedName ?? ""]
            var parent = coreDataNode.parentNode
            while let next = parent?.parentNode {
                path.append(next.decryptedName)
                parent = next
            }

            return "/" + path.reversed().dropFirst().joined(separator: "/")
        }
    }

    private func fileExtension(nodeName: String, mimeType: String) -> String {
        let (_, fileExtension) = nodeName.splitIntoNameAndExtension()
        if let fileExtension { return fileExtension }

        guard let fileUTI = UTType(tag: mimeType, tagClass: .mimeType, conformingTo: nil) else { return "-" }
        return fileUTI.preferredFilenameExtension ?? "-"
    }

    private func size(file: NodeDTO) -> String {
        guard let size = file.activeRevision?.storageSize else { return "..." }
        return ByteCountFormatter.storageSizeString(forByteCount: size)
    }

    private func makeExtendedAttributes(node: NodeDTO, attributes: ExtendedAttributes) -> [(key: String, value: String)] {
        if node.isProtonFile { return [] }
        let floatingStyle = FloatingPointFormatStyle<Double>().precision(.fractionLength(2))

        var array = [(key: String, value: String?)]()
        if let location = attributes.location {
            array += [
                ("Longitude", location.longitude.formatted(floatingStyle)),
                ("Latitude", location.latitude.formatted(floatingStyle))
            ]
        }
        if let camera = attributes.camera {
            let coordinates = camera.subjectCoordinates.map { subjectCoordinates in
                "top: \(subjectCoordinates.top), left: \(subjectCoordinates.left), bottom: \(subjectCoordinates.bottom), right: \(subjectCoordinates.right)"
            }
            array += [
                ("Device", camera.device),
                ("Orientation", camera.orientation.map(String.init)),
                ("Subject Coordinates", coordinates)
            ]
        }
        if let media = attributes.media {
            array += [
                ("Duration", media.duration?.formatted(floatingStyle)),
                ("Height", media.height?.formatted()),
                ("Width", media.width?.formatted())
            ]
        }
        return array.compactMap { tuple in
            guard let value = tuple.value else { return nil }
            return (tuple.key, value)
        }
    }
}
