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

import Combine
import PDCore
import UniformTypeIdentifiers
import PDLocalization

class NodeDetailsViewModel: ObservableObject {
    struct NodeDetailViewModel: Identifiable {
        let id: String
        let value: String
    }

    struct QADetails {
        let extendedAttributes: String
    }

    var node: Node
    var tower: Tower
    var qaDetails: QADetails?

    internal init(tower: Tower, node: Node) {
        self.tower = tower
        self.node = node
        initializeQaDetails()
    }
    
    private static var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .short
        return formatter
    }()
    
    lazy var title: String = {
        switch self.node {
        case is File:   return Localization.file_detail_title
        case is Folder: return Localization.folder_detail_title
        default:
            assert(false, "Undefined node type")
            return Localization.file_detail_general_title
        }
    }()
    
    lazy var details: [NodeDetailViewModel] = {
        if let file = node as? File {
            return makeFileDetails(with: file)
        } else if node is Folder {
            return detailsFolder
        } else {
            assert(false, "Undefined node type")
            return []
        }
    }()

    private func makeFileDetails(with file: File) -> [NodeDetailViewModel] {
        var details = self.detailsFolder
        details.append(contentsOf: [
            .init(id: Localization.file_detail_extension, value: self.fileExtension ?? "－")
        ])
        if !file.isProtonFile {
            details.append(contentsOf: [
                .init(id: Localization.file_detail_size, value: ByteCountFormatter.storageSizeString(forByteCount: Int64(file.size)))
            ])
        }
        let shareStatus: String
        if file.isNodeShared() {
            shareStatus = Localization.file_detail_share_yes
        } else {
            shareStatus = Localization.file_detail_share_no
        }
        details.append(contentsOf: [
            .init(id: Localization.file_detail_shared, value: shareStatus)
        ])
        return details
    }
    
    lazy var detailsFolder: [NodeDetailViewModel] = [
        .init(id: Localization.file_detail_name, value: node.decryptedName),
        .init(id: Localization.file_detail_uploaded_by, value: self.editorAddress),
        .init(id: Localization.file_detail_location, value: self.path),
        .init(id: Localization.file_detail_modified, value: Self.dateFormatter.string(from: node.modifiedDate))
    ]

    lazy var fileExtension: String? = { [unowned self] in
        guard let fileUTI = UTType(tag: self.node.mimeType, tagClass: .mimeType, conformingTo: nil) else { return nil }
        return fileUTI.preferredFilenameExtension
    }()
    
    lazy var editorAddress: String = {
        guard let signatureEmail = node.signatureEmail, !signatureEmail.isEmpty else {
            return Localization.file_detail_uploaded_by_anonymous
        }
        guard let address = self.tower.sessionVault.getAddress(for: signatureEmail) else {
            return signatureEmail
        }
        if address.displayName.isEmpty {
            return "\(address.email)"
        } else {
            return "\(address.displayName)\n\(address.email)"
        }
    }()
    
    lazy var path: String = {
        var path = [node.parentNode?.decryptedName ?? ""]
        var parent = node.parentNode
        while let next = parent?.parentNode {
            path.append(next.decryptedName)
            parent = next
        }
        
        return "/" + path.reversed().dropFirst().joined(separator: "/")
    }()

    private func initializeQaDetails() {
        guard Constants.buildType.isQaOrBelow else {
            return
        }

        guard let file = node as? File else {
            return
        }

        qaDetails = QADetails(extendedAttributes: makeExtendedAttributes(file: file))
    }

    private func makeExtendedAttributes(file: File) -> String {
        guard let revision = file.activeRevision else {
            return "error: no active revision"
        }

        do {
            let attributes = try revision.decryptedExtendedAttributes()
            let jsonEncoder = JSONEncoder()
            jsonEncoder.outputFormatting = .prettyPrinted
            let attributesData = try jsonEncoder.encode(attributes)
            return String(data: attributesData, encoding: .utf8) ?? "empty"
        } catch {
            return "error: \(error)"
        }
    }
}
